import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';

// Execute both production page readers; only UI state and transport are replaced.
const source = readFileSync(new URL('../entry/src/main/ets/pages/Index.ets', import.meta.url), 'utf8');
const methods = source.slice(source.indexOf('  private async refreshCareSummary('), source.indexOf('  private async readCareInvitations('));
assert.ok(methods.includes('private async readCareMembers('));
function deferred() {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return { promise, resolve, reject };
}
function setup() {
  const requests = [];
  let owner = 'A';
  const api = { current: () => ({ memberId: owner }), careMembers: () => {
    const request = deferred(); requests.push(request); return request.promise;
  } };
  class ApiError extends Error {}
  const Page = new Function('saydianApi', 'ApiError', `return ${stripTypeScriptTypes(`class Page {${methods}}`)}`)(api, ApiError);
  const page = new Page();
  Object.assign(page, { guest: false, careGeneration: 1, careSummaryGeneration: 0,
    careSummaryUpdatedAt: 0, careMembers: [], careMemberError: '', careFailure: error => error.message });
  return { page, requests, setOwner: value => owner = value };
}

test('old profile summary cannot overwrite a newer care member list', async () => {
  const { page, requests } = setup();
  const summary = page.refreshCareSummary(true);
  const list = page.readCareMembers(++page.careGeneration);
  requests[1].resolve([{ memberId: 2 }, { memberId: 3 }]); await list;
  requests[0].resolve([]); await summary;
  assert.equal(page.careMembers.length, 2);
});

test('old list cannot overwrite a newer summary or its error state', async () => {
  const { page, requests } = setup();
  const list = page.readCareMembers(page.careGeneration);
  const summary = page.refreshCareSummary(true);
  requests[1].resolve([{ memberId: 3 }]); await summary;
  requests[0].reject(new Error('old failure')); await list;
  assert.deepEqual(page.careMembers, [{ memberId: 3 }]);
  assert.equal(page.careMemberError, '');
});

test('a current empty response remains empty, while failure preserves records and permits retry', async () => {
  const { page, requests } = setup();
  page.careMembers = [{ memberId: 3 }];
  const failed = page.refreshCareSummary(true);
  requests[0].reject(new Error('服务暂不可用')); await failed;
  assert.equal(page.careMembers.length, 1);
  assert.equal(page.careMemberError, '服务暂不可用');
  assert.equal(page.careSummaryUpdatedAt, 0);
  const retry = page.refreshCareSummary();
  requests[1].resolve([]); await retry;
  assert.deepEqual(page.careMembers, []);
  assert.equal(page.careMemberError, '');
  assert.ok(page.careSummaryUpdatedAt > 0);
});

test('account or page generations reject late members even if the request itself succeeded', async () => {
  for (const accountChanged of [true, false]) {
    const { page, requests, setOwner } = setup();
    const reading = page.refreshCareSummary(true);
    if (accountChanged) setOwner('B'); else page.careGeneration++;
    requests[0].resolve([{ memberId: 3 }]); await reading;
    assert.deepEqual(page.careMembers, []);
    assert.equal(page.careSummaryUpdatedAt, 0);
  }
});
