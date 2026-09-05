import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks } from 'node:module';
registerHooks({ resolve(specifier, context, next) {
  return next(specifier.startsWith('.') && context.parentURL?.endsWith('.ts') && !/\.[a-z]+$/.test(specifier) ? `${specifier}.ts` : specifier, context);
} });
const { defaultDisplayUnits, parseDisplayUnits, displayHealthValue, profileDraftError, feedbackError } = await import('../entry/src/main/ets/model/DisplayPreferences.ts');
const { parseAddresses, parseInbox, orderStatusLabel, orderMatchesFilter, messageTime } = await import('../entry/src/main/ets/model/AccountPageContracts.ts');
const { AccountClient } = await import('../entry/src/main/ets/services/AccountClient.ts');
const { emptyAddressDraft, parseRegions, addressRegionChoices, selectAddressRegion, addressValidation } = await import('../entry/src/main/ets/model/AddressForm.ts');
const { ApiError } = await import('../entry/src/main/ets/model/Contracts.ts');
const { careGroupOptions, toggleCareGroup } = await import('../entry/src/main/ets/model/CareContracts.ts');
const now=Date.now(), response=data=>({code:200,data});
async function clientWith(request) {
  const vault={value:{accessToken:'synthetic',refreshToken:'synthetic-refresh',expiresAt:now+3600000,memberId:'1',displayName:'合成账号'},
    async read(){return this.value},async write(value){this.value=value},async clear(){this.value=undefined}};
  const client=new AccountClient({request},vault,()=>now);await client.restore();return client;
}
const profile={nickname:'合成昵称',gender:1,birthday:'1990-05-21',height:'172.0',weight:'65.5'};
test('display units convert copies only and tolerate unknown stored preferences',()=>{
  assert.deepEqual(parseDisplayUnits('bad','bad'),defaultDisplayUnits());
  const raw={name:'体温',value:36.5,unit:'°C'};
  assert.equal(displayHealthValue(raw,{distance:'mi',temperature:'f'}).value,97.7);
  assert.deepEqual(raw,{name:'体温',value:36.5,unit:'°C'});
  assert.equal(displayHealthValue({name:'距离',value:1.609344,unit:'km'},{distance:'mi',temperature:'c'}).value,1);
  assert.equal(displayHealthValue({name:'身高',value:172,unit:'cm'},{distance:'mi',temperature:'f'}).value,172);
});
test('sharing group selection preserves other groups and unknown server grants',()=>{
  const settings={enabled:['heartReat'],unknown:['futureMetric']};
  const daily=toggleCareGroup(settings,true);
  assert.equal(careGroupOptions(true).length,4);assert.equal(careGroupOptions(false).length,9);
  assert.equal(daily.enabled.length,5);assert.ok(daily.enabled.includes('heartReat'));
  assert.deepEqual(daily.unknown,['futureMetric']);assert.deepEqual(toggleCareGroup(daily,true),settings);
  assert.deepEqual(settings,{enabled:['heartReat'],unknown:['futureMetric']});
});
test('encyclopedia categories and selection use the same public endpoints as iOS',async()=>{
  const paths=[];const client=await clientWith(async(path)=>{paths.push(path);return response(path.includes('article-cate')?[{id:9,title:'合成分类'}]:[]);});
  assert.deepEqual(await client.articleCategories(),[{id:9,title:'合成分类'}]);
  assert.deepEqual(await client.articlesByCategory(9),[]);
  assert.deepEqual(paths,['/api/rf-article/article-cate/index?pid=3','/api/rf-article/article/index?page=1&cate_id=9']);
  await assert.rejects(client.articlesByCategory(-1));
});
test('profile validates real calendar dates and numeric ranges before saving',()=>{
  assert.equal(profileDraftError(profile),'');
  for(const birthday of ['2026-02-31','2026-13-01','2026-2-01','2099-01-01'])assert.ok(profileDraftError({...profile,birthday}));
  for(const height of ['abc','0','251','Infinity'])assert.ok(profileDraftError({...profile,height}));
  assert.ok(profileDraftError({...profile,nickname:' '}));
});
test('feedback form validates category, length and optional contact',()=>{
  assert.equal(feedbackError('设备连接','合成反馈内容',''),'');
  assert.ok(feedbackError('invalid','合成反馈内容',''));
  assert.ok(feedbackError('数据问题','短',''));
  assert.ok(feedbackError('数据问题','合成反馈内容','x'.repeat(101)));
});
test('profile save follows iOS form contract and rereads the same account',async()=>{
  const calls=[];const client=await clientWith(async(path,fields)=>{calls.push({path,fields});return response(path.endsWith('/my')?{id:1,...profile}:{});});
  const value=await client.saveProfile(profile);
  assert.equal(value.nickname,profile.nickname);
  assert.equal(calls[0].path,'/api/v1/member/member/save');
  assert.deepEqual(Object.fromEntries(calls[0].fields.map(f=>[f.name,f.value])),{...profile,gender:'1',height:'172'});
  assert.equal(calls[1].path,'/api/v1/member/member/my');
});
test('profile 404, offline and wrong identity cannot become save success',async()=>{
  for(const status of [0,404,405]){
    const client=await clientWith(async()=>{throw new ApiError('服务不可用',status)});
    await assert.rejects(client.saveProfile(profile));
  }
  const wrong=await clientWith(async path=>response(path.endsWith('/my')?{id:2}:{}));
  await assert.rejects(wrong.saveProfile(profile));
});
test('feedback only reports success after the server returns a stable id',async()=>{
  const client=await clientWith(async(path,fields)=>{assert.equal(path,'/api/v1/member/feedback');assert.equal(fields.find(f=>f.name==='type').value,'设备连接');return response({id:7});});
  assert.equal(await client.submitFeedback('设备连接','合成反馈内容',''),'7');
  const bad=await clientWith(async()=>response({}));await assert.rejects(bad.submitFeedback('设备连接','合成反馈内容',''));
});
test('inbox uses authenticated member type 2 and excludes malformed responses',async()=>{
  const client=await clientWith(async path=>{assert.equal(path,'/api/v1/member/notify?page=1&type=2');return response([]);});
  assert.deepEqual(await client.inbox(),[]);
  for(const data of [undefined,{},'bad',[{}]])assert.throws(()=>parseInbox(data));
  assert.equal(parseInbox([{id:1,title:'关爱请求',is_read:'0',event_type:'care_invitation'},{id:1}]).length,1);
  const values=parseInbox([{id:1,title:'<b>消息</b>',content:'通知',is_read:'1',kind:'health_warning'}]);
  assert.equal(values[0].title,'消息');assert.equal(values[0].read,true);assert.equal(values[0].kind,'health_warning');
});
test('notification timestamps use readable local dates in seconds or milliseconds',()=>{
  const value=new Date(2026,8,6,15,4).getTime();
  assert.equal(messageTime(value),'2026-09-06 15:04');
  assert.equal(messageTime(value/1000),'2026-09-06 15:04');
  assert.equal(messageTime(0),'');assert.equal(messageTime(undefined),'');
});
test('addresses expose only shipping fields and malformed data is not an empty state',()=>{
  const values=parseAddresses([{id:1,realname:'合成收货人',mobile:'10000000001',address_name:'合成地区',address_details:'合成地址',is_default:1,password:'never-keep'}]);
  assert.equal(values[0].address,'合成地区合成地址');assert.equal(values[0].isDefault,true);
  assert.equal(JSON.stringify(values).includes('password'),false);assert.throws(()=>parseAddresses({}));
});
const regionData={provinces:{110000:'北京市',120000:'天津市'},cities:{110100:'市辖区',120100:'市辖区'},areas:{110101:'东城区',120101:'和平区'}};
const regions=parseRegions(JSON.stringify(regionData));
const addressDraft={...emptyAddressDraft(),name:'合成收货人',mobile:'10000000001',details:'合成测试地址',province:'110000',city:'110100',area:'110101'};
test('address regions use the exact read-only iOS data with cascading selection',()=>{
  const source=readFileSync(new URL('../../assets/china_regions.json',import.meta.url));
  assert.deepEqual(readFileSync(new URL('../entry/src/main/resources/rawfile/china_regions.json',import.meta.url)),source);
  assert.equal(Object.keys(parseRegions(source.toString()).provinces).length,34);
  assert.deepEqual(addressRegionChoices(regions,addressDraft,2),[{code:'110101',name:'东城区'}]);
  const changed=selectAddressRegion(addressDraft,0,'120000');
  assert.equal(changed.city,'');assert.equal(changed.area,'');assert.equal(addressDraft.city,'110100');
  assert.deepEqual(addressRegionChoices(regions,changed,2),[]);
  assert.ok(addressValidation({...addressDraft,area:'120101'},regions));
  for(const value of ['bad','null','{}','{"provinces":[]}'])assert.throws(()=>parseRegions(value));
});
test('address creation and editing preserve the iOS JSON and HTTP methods',async()=>{
  const calls=[];const client=await clientWith(async(path,fields,session,jsonBody,method)=>{calls.push({path,fields,session,jsonBody,method});return response({id:7,...JSON.parse(jsonBody)});});
  assert.equal((await client.saveAddress(addressDraft,regions)).id,'7');
  assert.equal((await client.saveAddress({...addressDraft,id:'7',isDefault:false},regions)).id,'7');
  assert.equal(calls[0].method,'POST');assert.equal(calls[0].path,'/api/v1/member/address');
  assert.equal(calls[1].method,'PUT');assert.equal(calls[1].path,'/api/v1/member/address/7');
  assert.deepEqual(JSON.parse(calls[1].jsonBody),{realname:addressDraft.name,mobile:addressDraft.mobile,address_details:addressDraft.details,
    is_default:0,region:'北京市 市辖区 东城区',province_id:110000,city_id:110100,area_id:110101});
  assert.ok(calls[0].session);assert.equal(calls[0].fields,undefined);
});
test('invalid address, failed save, and mismatched response cannot report success',async()=>{
  let calls=0;const client=await clientWith(async()=>{calls++;return response({});});
  for(const draft of [{...addressDraft,name:''},{...addressDraft,mobile:'bad'},{...addressDraft,details:''},{...addressDraft,area:'120101'}])await assert.rejects(client.saveAddress(draft,regions));
  assert.equal(calls,0);await assert.rejects(client.saveAddress(addressDraft,regions));
  const wrong=await clientWith(async()=>response({id:8}));await assert.rejects(wrong.saveAddress({...addressDraft,id:'7'},regions));
  for(const status of [0,404,405]){
    const failing=await clientWith(async()=>{throw new ApiError('服务暂不可用',status)});await assert.rejects(failing.saveAddress(addressDraft,regions));assert.ok(failing.current());
  }
});
test('completed and refund order status mirrors iOS instead of cancelled',()=>{
  for(const status of [3,4])assert.equal(orderStatusLabel(status),'已完成');
  assert.equal(orderStatusLabel(-1),'申请退款');assert.equal(orderStatusLabel(-2),'退款中');assert.equal(orderStatusLabel(-3),'已退款');
  assert.ok(orderMatchesFilter(4,3));assert.ok(orderMatchesFilter(-2,-1));assert.equal(orderMatchesFilter(0,3),false);
});
test('order filter reaches the server instead of only filtering the first all-orders page',async()=>{
  const paths=[];const client=await clientWith(async(path)=>{paths.push(path);return response([]);});
  for(const status of [99,0,1,2,3,-1])await client.shopOrders(status);
  assert.equal(paths[0],'/api/inv-shop/v1/member/order/index?page=1');
  assert.deepEqual(paths.slice(1),[0,1,2,3,-1].map(status=>`/api/inv-shop/v1/member/order/index?page=1&synthesize_status=${status}`));
  await assert.rejects(client.shopOrders(88));assert.equal(paths.length,6);
});
test('reset password validates before using the existing iOS endpoint',async()=>{
  const calls=[];const client=await clientWith(async(path,fields)=>{calls.push({path,fields});return response({access_token:'new-synthetic',expiration_time:3600,member:{id:1}});});
  await assert.rejects(client.resetPassword('bad','123456','123456','123456'));assert.equal(calls.length,0);
  await client.resetPassword('10000000001','123456','123456','123456');
  assert.equal(calls[0].path,'/api/v1/site/up-pwd');assert.equal(calls[0].fields.find(f=>f.name==='group').value,'app');
});
test('native inner pages keep operational forms, routes and fixed payment footer',()=>{
  const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
  for(const id of ['save_profile','profile_birthday','submit_feedback','contact_phone','contact_copy','submit_reset','account_addresses',
    'trend_calendar','trend_period_','health_trend_chart','all_trend_records','care_sharing','care_invitations'])assert.ok(source.includes(id),id);
  assert.equal((source.match(/id\('confirm_payment'\)/g)||[]).length,1);
  const alerts=source.slice(source.indexOf('  HealthAlertContent()'),source.indexOf('  ShopHomeContent()'));
  assert.doesNotMatch(alerts,/notificationCount/);assert.match(alerts,/healthWarnings/);
  assert.match(source,/message\.kind === 'health_warning'/);
  assert.match(source,/innerParents\.get\(this\.screen\)/);
  for(const status of [0,1,2,-1])assert.ok(source.includes(`this.openOrders(${status})`));
  for(const id of ['add_address_header','address_name','address_mobile','address_region_','save_address'])assert.ok(source.includes(id));
  const capture=readFileSync(new URL('../../test/support/ios_inner_page_capture.dart',import.meta.url),'utf8');
  assert.match(capture,/'addresses': shop\.ShopAddressBookPage/);
  const profileRefresh=source.slice(source.indexOf('private async refreshProfile()'),source.indexOf('private async signOut()'));
  assert.match(profileRefresh,/this\.clearAccountForms\(\)/);
  const messageOpen=source.slice(source.indexOf('private async openInboxMessage('),source.indexOf('private async refreshPermissions('));
  assert.match(messageOpen,/this\.readInvitationMessage\(message\.id\)/);
  assert.match(messageOpen,/await saydianApi\.readInboxMessage\(id\)/);
});
