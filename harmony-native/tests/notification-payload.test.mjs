import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { normalizeNotificationPayload } from '../entry/src/main/ets/model/NotificationPayload.ts';

const fixtures = JSON.parse(readFileSync(new URL('../../test/fixtures/notification_contracts.json', import.meta.url)));
for (const fixture of fixtures) {
  test(`notification parity: ${fixture.name}`, () => {
    for (const payload of [fixture.payload, { extras: { 'cn.jpush.android.EXTRA': JSON.stringify(fixture.payload) } }]) {
      const result = normalizeNotificationPayload(payload);
      if (fixture.rejected) { assert.equal(result, undefined); continue; }
      assert.deepEqual(result, {
        eventId: fixture.eventId, eventType: fixture.type, entityId: fixture.entityId,
        route: fixture.type === 'care_invitation' ? 'care-invitations' : 'health-alerts'
      });
    }
  });
}

test('cyclic and oversized SDK envelopes are bounded', () => {
  const cyclic = {}; cyclic.extras = cyclic;
  assert.equal(normalizeNotificationPayload(cyclic), undefined);
  assert.equal(normalizeNotificationPayload({ extras: ' '.repeat(20000) }), undefined);
});
