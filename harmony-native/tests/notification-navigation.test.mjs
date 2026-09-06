import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { registerHooks, stripTypeScriptTypes } from 'node:module';

registerHooks({
  resolve(specifier, context, next) {
    if (specifier.startsWith('.') && context.parentURL?.endsWith('.ets') && !/\.[a-z]+$/.test(specifier)) {
      return next(specifier + '.ts', context);
    }
    return next(specifier, context);
  },
  load(url, context, next) {
    if (url.endsWith('.ets')) return { format: 'module',
      source: stripTypeScriptTypes(readFileSync(new URL(url), 'utf8')), shortCircuit: true };
    return next(url, context);
  }
});
const storage = new Map();
globalThis.AppStorage = { has: key => storage.has(key), get: key => storage.get(key),
  setOrCreate: (key, value) => storage.set(key, value) };
const { captureNotificationEvent, clearNotificationSession, initializeNotificationNavigation,
  PENDING_NOTIFICATION_ROUTE, NOTIFICATION_REVISION, setNotificationOwner, notificationMatchesOwner,
  observeNotificationArrival } =
  await import('../entry/src/main/ets/services/NotificationNavigation.ets');
const event = { eventId: 'fixture-care-1', type: 'care_invitation', deepLink: '/care/invitations/42' };

test('arrival refreshes once without navigating; opening reads the allowed destination once', () => {
  storage.clear(); clearNotificationSession();
  captureNotificationEvent(event, false);
  assert.equal(storage.get(NOTIFICATION_REVISION), 1);
  assert.equal(storage.get(PENDING_NOTIFICATION_ROUTE), '');
  captureNotificationEvent(event, false);
  assert.equal(storage.get(NOTIFICATION_REVISION), 1);
  captureNotificationEvent(event, true);
  assert.equal(storage.get(PENDING_NOTIFICATION_ROUTE), 'care-invitations');
  storage.set(PENDING_NOTIFICATION_ROUTE, '');
  captureNotificationEvent(event, true);
  assert.equal(storage.get(PENDING_NOTIFICATION_ROUTE), '');
});

test('cold initialization retains a queued click, and logout drops its navigation and dedupe scope', () => {
  clearNotificationSession(); captureNotificationEvent(event, true);
  initializeNotificationNavigation();
  assert.equal(storage.get(PENDING_NOTIFICATION_ROUTE), 'care-invitations');
  clearNotificationSession();
  assert.equal(storage.get(PENDING_NOTIFICATION_ROUTE), '');
  captureNotificationEvent(event, true);
  assert.equal(storage.get(PENDING_NOTIFICATION_ROUTE), 'care-invitations');
});

test('a reused event ID cannot change entity or route; untrusted payloads never navigate', () => {
  clearNotificationSession(); captureNotificationEvent(event, false);
  const revision = storage.get(NOTIFICATION_REVISION);
  captureNotificationEvent({ ...event, deepLink: '/care/invitations/43' }, true);
  captureNotificationEvent({ ...event, deepLink: 'https://untrusted.example' }, true);
  assert.equal(storage.get(PENDING_NOTIFICATION_ROUTE), '');
  assert.equal(storage.get(NOTIFICATION_REVISION), revision);
});

test('local notification clicks retain recipient scope through cold login and reject another account', () => {
  storage.clear();clearNotificationSession();
  const local={...event,event_id:undefined,eventId:'local-1',local_notice_owner:'1'};
  captureNotificationEvent(local,true);assert.equal(storage.get(PENDING_NOTIFICATION_ROUTE),'care-invitations');
  assert.equal(notificationMatchesOwner('2'),false);setNotificationOwner('2');
  assert.equal(storage.get(PENDING_NOTIFICATION_ROUTE),'');
  captureNotificationEvent({...local,eventId:'local-2'},true);assert.equal(storage.get(PENDING_NOTIFICATION_ROUTE),'');
  setNotificationOwner('');captureNotificationEvent({...local,eventId:'local-3'},true);setNotificationOwner('1');
  assert.equal(notificationMatchesOwner('1'),true);assert.equal(storage.get(PENDING_NOTIFICATION_ROUTE),'care-invitations');
});

test('remote arrival hook receives only normalized identity, local generated clicks never trigger a remote refresh', () => {
  storage.clear();clearNotificationSession();const received=[];
  observeNotificationArrival((payload,opened)=>received.push({payload,opened}));
  captureNotificationEvent({...event,mobile:'10000000000',value:199},false);
  assert.deepEqual(received,[{payload:{eventId:'fixture-care-1',eventType:'care_invitation',entityId:'42',route:'care-invitations'},opened:false}]);
  captureNotificationEvent({...event,eventId:'local-only',local_notice_owner:'1'},true);
  assert.equal(received.length,1);
});
