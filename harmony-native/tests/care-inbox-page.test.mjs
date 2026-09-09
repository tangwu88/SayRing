import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import { careInboxUnread, mergeCareInbox } from '../entry/src/main/ets/model/ForegroundCareNotifications.ts';
const source=readFileSync(new URL('../entry/src/main/ets/pages/Index.ets',import.meta.url),'utf8');
const methods=source.slice(source.indexOf('  private async refreshInbox('),source.indexOf('  private async refreshPermissions('))+
  source.slice(source.indexOf('  private async refreshNotificationCount('),source.indexOf('  private async connectPush('));
const deferred=()=>{let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b});return{promise,resolve,reject}};
function harness(){
  let generation=1;const inboxRequests=[],unreadRequests=[],reads=[],marked=[];
  const local=[{id:-42,entityId:'42',source:'local',kind:'care_invitation',read:false,title:'新的关爱邀请'}];
  const api={healthSession:()=>({ownerId:'1',generation}),current:()=>({memberId:'1'}),
    inbox(){const p=deferred();inboxRequests.push(p);return p.promise},
    notificationUnread(){const p=deferred();unreadRequests.push(p);return p.promise},
    async readInboxMessage(id){reads.push(id);return{id}}};
  class ApiError extends Error {}
  const care={currentInbox:()=>local,async markRead(id){marked.push(id);local.find(item=>-item.id===id).read=true}};
  const Page=new Function('saydianApi','careNotifications','careInboxUnread','mergeCareInbox','ApiError',
    `return ${stripTypeScriptTypes(`class Page {${methods}}`)}`)(api,care,careInboxUnread,mergeCareInbox,ApiError);
  const page=new Page();Object.assign(page,{guest:false,inbox:[],inboxLoading:false,inboxError:'',serverInbox:[],serverUnread:undefined,
    inboxGeneration:0,unreadGeneration:0,notificationCount:-1,screen:'messages',async openCare(){this.screen='care'},accountFormFailure:()=>{},careFailure:()=>{}});
  return{page,inboxRequests,unreadRequests,reads,marked,switch(){generation++;page.clearInboxState()}};
}
test('page shows persisted local unread even when server inbox fails, no fabricated server read',async()=>{
  const h=harness();const pending=h.page.refreshInbox();assert.equal(h.page.inbox[0].id,-42);assert.equal(h.page.notificationCount,1);
  h.inboxRequests[0].reject(new Error('404'));await pending;assert.equal(h.page.inbox[0].id,-42);assert.match(h.page.inboxError,/暂未更新/);
  h.unreadRequests[0].resolve(undefined);await new Promise(resolve=>setImmediate(resolve));assert.equal(h.page.notificationCount,1);
  await h.page.openInboxMessage(h.page.inbox[0]);assert.deepEqual(h.marked,[42]);assert.deepEqual(h.reads,[]);
  assert.equal(h.page.screen,'care-invitations');assert.equal(h.page.notificationCount,0);
});
test('old same-owner login generation cannot replace new inbox or clear its loading lock',async()=>{
  const h=harness();const old=h.page.refreshInbox();h.switch();const newer=h.page.refreshInbox();
  h.inboxRequests[0].resolve([{id:1,kind:'system',read:false}]);await old;assert.equal(h.page.inboxLoading,true);
  assert.equal(h.page.serverInbox.length,0);h.inboxRequests[1].resolve([{id:2,kind:'system',read:false}]);await newer;
  assert.equal(h.page.serverInbox[0].id,2);h.unreadRequests[0].resolve(1);
});
test('out-of-order unread counts do not overwrite a more recent refresh',async()=>{
  const h=harness();const old=h.page.refreshNotificationCount(),newer=h.page.refreshNotificationCount();
  h.unreadRequests[1].resolve(2);await newer;h.unreadRequests[0].resolve(19);await old;
  assert.equal(h.page.notificationCount,3);assert.equal(h.page.serverUnread,2);
});

test('production signOut pauses notifications synchronously before awaiting unregister or account cleanup',async()=>{
  const method=source.slice(source.indexOf('  private async signOut('),source.indexOf('  private showFeature('));
  const events=[], unregister=deferred();
  const Page=new Function('saydianApi','careNotifications',`return ${stripTypeScriptTypes(`class Page {${method}}`)}`)(
    {async logout(){events.push('account-cleared')}},{beginSignOut(){events.push('notifications-paused')}});
  const page=new Page();Object.assign(page,{busy:false,pageGeneration:1,clearCareState(){},clearAccountForms(){},
    async releasePushBeforeLogout(){events.push('unregister-start');await unregister.promise}});
  const work=page.signOut();assert.deepEqual(events,['notifications-paused','unregister-start']);
  unregister.resolve();await work;assert.deepEqual(events,['notifications-paused','unregister-start','account-cleared']);
  assert.equal(page.guest,true);assert.equal(page.busy,false);
});
