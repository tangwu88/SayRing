import test from 'node:test';
import assert from 'node:assert/strict';
import { ForegroundCareNotifications, emptyCareNoticeState, parseCareNoticeState, localCareInbox,
  mergeCareInbox, careInboxUnread } from '../entry/src/main/ets/model/ForegroundCareNotifications.ts';

const turn = async () => { for (let i = 0; i < 4; i++) await new Promise(resolve => setImmediate(resolve)); };
const invite = (id, state = 'pending') => ({ id, state, inviterId: 88, name: '测试夹具', mobile: '10000000000' });
const later = () => { let resolve, reject; const promise = new Promise((a,b) => { resolve=a;reject=b; }); return {promise,resolve,reject}; };
function harness(options = {}) {
  const persisted = options.persisted ?? new Map(), timers = new Map(), delays = [], alerts = [], notices = [];
  let next = 0, reads = 0, changed = 0, failed = 0, list = [], error;
  const port = {
    store: {
      async read(owner) { return parseCareNoticeState(persisted.get(owner) ?? ''); },
      async save(owner, state, current) { current(); if(options.save) await options.save(); current(); persisted.set(owner,JSON.stringify(state)); }
    },
    async readInvitations() { reads++; if(options.read) return await options.read(); if(error) throw error; return list; },
    now: () => Date.UTC(2026,8,7),
    schedule(fn, ms) { delays.push(ms); timers.set(++next,fn); return next; },
    cancel(id) { timers.delete(id); }, changed() { changed++; }, arrived(count) { alerts.push(count); }, failed() { failed++; },
    async notify(owner,item,current) { current(); if(options.notify) await options.notify(); current(); notices.push({owner,id:item.id}); }
  };
  const controller = new ForegroundCareNotifications(port);
  return { controller, persisted, timers, delays, alerts, notices,
    get reads(){return reads}, get failed(){return failed}, get changed(){return changed},
    list(value){list=value}, error(value){error=value},
    start(owner='1', generation=1) {controller.setSession({ownerId:owner,generation});controller.setForeground(true)},
    fire() {const first=timers.entries().next().value; assert.ok(first);timers.delete(first[0]);first[1]();}
  };
}

test('login/start immediate; foreground-only 30 seconds; resume immediate and no overlapping timer requests', async () => {
  const h=harness(); h.start();await turn();assert.equal(h.reads,1);assert.deepEqual(h.delays,[30000]);
  h.fire();await turn();assert.equal(h.reads,2);h.controller.setForeground(false);assert.equal(h.timers.size,0);
  h.controller.refresh();await turn();assert.equal(h.reads,2);
  h.controller.setForeground(true);await turn();assert.equal(h.reads,3);assert.equal(h.timers.size,1);
});

test('failed reads back off 30/60/120/300 seconds; recover returns to 30 and stores no fake messages', async () => {
  const h=harness();h.error(new Error('offline'));h.start();await turn();
  for(let i=0;i<4;i++){h.fire();await turn()}
  assert.deepEqual(h.delays,[30000,60000,120000,300000,300000]);assert.equal(h.persisted.size,0);assert.equal(h.alerts.length,0);
  h.error(undefined);h.fire();await turn();assert.equal(h.delays.at(-1),30000);
});

test('only real pending IDs persist; repeat, process restart and handled invitations do not alert again', async () => {
  const h=harness();h.list([invite(4),invite(4),invite(5,'accepted')]);h.start();await turn();
  assert.deepEqual(h.alerts,[1]);assert.deepEqual(h.notices,[{owner:'1',id:4}]);
  assert.equal(h.controller.currentInbox()[0].id,-4);assert.equal(h.controller.currentInbox()[0].read,false);
  assert.doesNotMatch(h.persisted.get('1'),/测试夹具|10000000000|inviterId|mobile/);
  h.fire();await turn();assert.equal(h.alerts.length,1);
  h.controller.setForeground(false);
  const restart=harness({persisted:h.persisted});restart.list([invite(4)]);restart.start();await turn();assert.equal(restart.alerts.length,0);
  restart.list([invite(4,'accepted')]);restart.fire();await turn();assert.equal(restart.controller.currentInbox()[0].read,true);
  assert.match(restart.controller.currentInbox()[0].title,/已更新/);
});

test('notification permission rejected keeps persistent unread and does not repeat sound/toast on retry', async () => {
  const h=harness({notify:async()=>{throw new Error('denied')}});h.list([invite(7)]);h.start();await turn();
  assert.equal(h.controller.currentInbox()[0].read,false);assert.equal(h.persisted.size,1);assert.deepEqual(h.alerts,[1]);
  h.fire();await turn();assert.deepEqual(h.alerts,[1]);assert.equal(h.failed,0);
});

test('logout / account generation changes invalidate late network and queued persistence and notification', async () => {
  const late=later();const h=harness({read:()=>late.promise});h.start();await turn();
  h.controller.setSession({ownerId:'',generation:2});late.resolve([invite(8)]);await turn();
  assert.equal(h.persisted.size,0);assert.equal(h.notices.length,0);assert.deepEqual(h.controller.currentInbox(),[]);
  const save=later();const s=harness({save:()=>save.promise});s.list([invite(9)]);s.start();await turn();
  s.controller.setSession({ownerId:'2',generation:3});save.resolve();await turn();
  assert.equal(s.persisted.has('1'),false);assert.ok(s.notices.every(n=>n.owner==='2'));
});

test('background invalidates late results and scheduled notifications, resume performs real read again', async () => {
  const late=later();const h=harness({read:()=>late.promise});h.start();await turn();h.controller.setForeground(false);
  late.resolve([invite(10)]);await turn();assert.equal(h.persisted.size,0);assert.equal(h.alerts.length,0);assert.equal(h.timers.size,0);
  h.controller.setForeground(true);await turn();assert.equal(h.reads,2);assert.equal(h.notices.length,1);
});

test('remote entity before poll is verified against API and never creates a second local alert', async () => {
  const h=harness();h.start();await turn();h.controller.remoteArrived('999');await turn();assert.equal(h.controller.currentInbox().length,0);
  h.list([invite(12)]);h.controller.remoteArrived('12');await turn();assert.equal(h.controller.currentInbox().length,1);
  assert.equal(h.alerts.length,0);assert.equal(h.notices.length,0);
  h.controller.remoteArrived('12');await turn();assert.equal(h.controller.currentInbox().length,1);
});

test('local first then remote with another event ID keeps one record and one local alert', async () => {
  const h=harness();h.list([invite(13)]);h.start();await turn();h.controller.remoteArrived('13');await turn();
  assert.equal(h.controller.currentInbox().length,1);assert.deepEqual(h.alerts,[1]);assert.equal(h.notices.length,1);
});

test('empty/partial/unknown invitation results do not mark missing pending messages read or cancelled', async () => {
  const h=harness();h.list([invite(14)]);h.start();await turn();
  for(const list of [[],[invite(19)],[invite(14,'other')]]) {
    h.list(list);h.fire();await turn();const item=h.controller.currentInbox().find(row=>row.id===-14);
    assert.equal(item.read,false);assert.equal(item.title,'新的关爱邀请');
  }
  h.list([invite(14,'rejected')]);h.fire();await turn();
  assert.equal(h.controller.currentInbox().find(row=>row.id===-14).read,true);
});

test('read persists for this account only; offline start still displays prior local inbox', async () => {
  const h=harness();h.list([invite(15)]);h.start();await turn();await h.controller.markRead(15);
  assert.equal(h.controller.currentInbox()[0].read,true);h.controller.setSession({ownerId:'2',generation:2});await turn();
  assert.equal(h.controller.currentInbox()[0].read,false);assert.equal(JSON.parse(h.persisted.get('1')).entries[0].read,true);
  h.controller.setForeground(false);const offline=harness({persisted:h.persisted});offline.error(new Error('offline'));offline.start('1');await turn();
  assert.equal(offline.controller.currentInbox()[0].read,true);
});

test('corrupt local state is not cleared/replaced or presented as successfully persisted', async () => {
  const persisted=new Map([['1','{broken']]);const h=harness({persisted});h.list([invite(16)]);h.start();await turn();
  assert.equal(persisted.get('1'),'{broken');assert.equal(h.alerts.length,0);assert.equal(h.failed,1);
});

test('merged inbox and unread deduplicate explicit entity IDs, preserve unmatched server messages', () => {
  const state=emptyCareNoticeState();state.seen=[17,18];state.entries=[17,18].map(id=>({id,receivedAt:1000,read:false,pending:true}));
  const local=localCareInbox(state), server=[{id:91,kind:'care_invitation',entityId:'17',read:false}];
  assert.equal(mergeCareInbox(server,local).length,2);assert.equal(careInboxUnread(1,server,local),2);
  assert.equal(careInboxUnread(undefined,server,local),2);assert.equal(careInboxUnread(4,server,local),5);
  assert.equal(mergeCareInbox([{id:92,kind:'system',read:false}],local).length,3);
});
