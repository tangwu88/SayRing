import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdir, mkdtemp, readFile, readdir, realpath, rm, symlink, writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {basename, dirname, join, resolve} from 'node:path';
import {test} from 'node:test';
import {fileURLToPath} from 'node:url';
import {privateRecordName, runGlobalAuthAccountQa, validatePrivateDirectory} from './global_auth_account_qa.mjs';

const origin = 'https://app.saydian.cn';
const prefix = '/global/api/saydian-app/v2';
const secret = 'PRIVATE_FIXTURE_DO_NOT_LOG';
const memberId = 'fixture-private-member-id';
const version = 'fixture-reviewed-v1';
const id = '12345678-1234-1234-1234-123456789abc';
const json = (data, status = 200) => new Response(JSON.stringify(data), {status, headers: {'Content-Type': 'application/json'}});
const ok = (data, status = 200) => json({code: 200, data, message: secret, requestId: id}, status);
const deny = () => json({code: 401, data: null, message: secret, requestId: id}, 401);
const caps = () => ({realm: 'global', supportedLocales: ['en'],
  registration: {email: true, sms: false, verificationRequired: false}, consentVersion: version,
  legal: Object.fromEntries([['userAgreement', 'user_agreement'], ['privacyPolicy', 'privacy_policy']].map(([key, type]) =>
    [key, {path: `/api/saydian-app/v2/content/legal/${type}?version=${version}&locale=en`}]))});

async function directory(t) {
  const root = await mkdtemp(join(tmpdir(), 'saydian-account-qa-'));
  const canonical = await realpath(root);
  t.after(async () => {
    // Only this exact newly allocated synthetic fixture directory is removed.
    assert.equal(basename(canonical).startsWith('saydian-account-qa-'), true);
    assert.equal(dirname(canonical).toLowerCase(), (await realpath(tmpdir())).toLowerCase());
    await rm(canonical, {recursive: true, force: true});
  });
  return root;
}

function backend(override = () => undefined) {
  const calls = [];
  const sessions = [];
  let account;
  let serial = 0;
  const issue = (existing) => {
    const session = existing ?? {member: {id: memberId}};
    Object.assign(session, {accessToken: `fixture-access-${++serial}`, refreshToken: `fixture-refresh-${serial}`, expiresAt: '2099-01-01T00:00:00Z', revoked: false});
    if (!existing) sessions.push(session);
    return {...session};
  };
  const f = {calls, sessions, get account() { return account; }, fetchImpl: async (url, options) => {
    assert.equal(url.startsWith(`${origin}/global/`), true);
    assert.equal(new URL(url).origin, origin);
    assert.equal(options.redirect, 'error');
    assert.equal(options.credentials, 'omit');
    const path = new URL(url).pathname;
    const method = options.method;
    const body = options.body ? JSON.parse(options.body) : undefined;
    const token = options.headers.Authorization?.replace('Bearer ', '');
    calls.push({path, method, body, token});
    const changed = override({url, path, method, body, token, calls, sessions, issue});
    if (changed !== undefined) return changed;
    if (method === 'GET' && path === '/global/health/ready') return json({status: 'ready', database: 'ok'});
    if (method === 'GET' && path === `${prefix}/auth/capabilities`) return ok(caps());
    if (method === 'GET' && path.startsWith(`${prefix}/content/legal/`)) return ok({documentType: path.split('/').at(-1), locale: 'en', version, reviewed: true, contentHtml: '<p>Reviewed fixture</p>'});
    if (method === 'GET' && path === `${prefix}/members/me`) {
      const current = sessions.find((value) => value.accessToken === token && !value.revoked);
      return current ? ok({id: memberId, nickname: secret}) : deny();
    }
    if (method === 'POST' && path === `${prefix}/auth/register`) {
      assert.equal(account, undefined);
      assert.equal(body.channel, 'email'); assert.equal(body.locale, 'en'); assert.equal(body.consentVersion, version);
      assert.equal(/^saydian-qa-[a-f0-9]{24}@example\.invalid$/.test(body.identifier), true);
      assert.equal(/^[a-zA-Z0-9_-]{32}$/.test(body.password), true);
      assert.equal(token, undefined);
      account = {email: body.identifier, password: body.password};
      return ok(issue(), 201);
    }
    if (method === 'POST' && path === `${prefix}/auth/login`) {
      assert.equal(body.username === account.email && body.password === account.password, true);
      assert.equal(token, undefined);
      return ok(issue(), 201);
    }
    if (method === 'POST' && path === `${prefix}/auth/refresh`) {
      assert.equal(token, undefined);
      const current = sessions.find((value) => value.refreshToken === body.refreshToken && !value.revoked);
      return current ? ok(issue(current), 201) : deny();
    }
    if (method === 'POST' && path === `${prefix}/auth/logout`) {
      assert.equal(body, undefined);
      const current = sessions.find((value) => value.accessToken === token && !value.revoked);
      if (!current) return deny();
      current.revoked = true;
      return ok({loggedOut: true}, 201);
    }
    throw new Error('Unexpected synthetic request');
  }};
  return f;
}
const options = (privateDirectory, f, extra = {}) => ({allowIsolatedQaAccount: true, privateDirectory,
  fetchImpl: f.fetchImpl, permissionCheck: async () => true, timeoutMs: 100, ...extra});
const publicPrivacy = (result, credentials) => {
  const output = JSON.stringify(result);
  for (const value of [secret, memberId, 'fixture-access-', 'fixture-refresh-', credentials?.email, credentials?.password].filter(Boolean)) {
    assert.equal(output.includes(value), false);
  }
};

test('absent opt-in performs no file or network operation', async () => {
  const f = backend();
  const result = await runGlobalAuthAccountQa({fetchImpl: f.fetchImpl});
  assert.equal(result.passed, false); assert.equal(f.calls.length, 0);
});
test('invalid CLI flags cannot supply a URL, real contact or password', () => {
  const result = spawnSync(process.execPath, [fileURLToPath(new URL('./global_auth_account_qa.mjs', import.meta.url)), '--username', secret], {encoding: 'utf8'});
  assert.equal(result.status, 2); assert.equal(result.stdout.includes(secret), false); assert.equal(result.stderr, '');
});
test('nonexistent, relative and unsafe-permission directories fail before requests', async (t) => {
  const root = await directory(t);
  for (const dir of ['relative', join(root, 'missing'), root]) {
    const f = backend();
    const result = await runGlobalAuthAccountQa(options(dir, f, {permissionCheck: async () => false}));
    assert.equal(result.passed, false); assert.equal(f.calls.length, 0);
  }
});
test('repository, nested directory and repository ancestor are rejected', async (t) => {
  const root = await directory(t); const repo = join(root, 'repo'); const nested = join(repo, 'private');
  await mkdir(nested, {recursive: true});
  for (const dir of [root, repo, nested]) {
    await assert.rejects(validatePrivateDirectory(dir, {repositoryDirectory: repo, permissionCheck: async () => true}));
  }
});
test('directory symlink/junction is rejected after resolving its actual target', async (t) => {
  const root = await directory(t); const repo = join(root, 'repo'); const link = join(root, 'link');
  await mkdir(repo); await symlink(repo, link, process.platform === 'win32' ? 'junction' : 'dir');
  await assert.rejects(validatePrivateDirectory(link, {repositoryDirectory: repo, permissionCheck: async () => true}));
});

test('Windows ACL validation works without PowerShell module discovery', {skip: process.platform !== 'win32'}, async (t) => {
  const root = await directory(t);
  const privateFixture = join(root, 'private-acl');
  await mkdir(privateFixture);
  // Restrict only this newly allocated test fixture. No operator directory or
  // real credential file is read or changed by the test.
  const command = `$ErrorActionPreference='Stop'; $PSModuleAutoLoadingPreference='None'; `
    + `$p=$env:SAYDIAN_QA_ACL_FIXTURE; $u=[System.Security.Principal.WindowsIdentity]::GetCurrent().User; `
    + `$a=[System.Security.AccessControl.DirectorySecurity]::new(); $a.SetOwner($u); $a.SetAccessRuleProtection($true,$false); `
    + `$r=[System.Security.AccessControl.FileSystemAccessRule]::new($u,'FullControl','ContainerInherit,ObjectInherit','None','Allow'); `
    + `$a.AddAccessRule($r); [System.IO.Directory]::SetAccessControl($p,$a)`;
  const setup = spawnSync(join(process.env.SystemRoot, 'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'),
    ['-NoProfile', '-NonInteractive', '-Command', command], {windowsHide: true, timeout: 5000,
      encoding: 'utf8', env: {...process.env, SAYDIAN_QA_ACL_FIXTURE: privateFixture, PSModulePath: ''}});
  assert.equal(setup.status, 0);
  const previous = process.env.PSModulePath;
  process.env.PSModulePath = '';
  try {
    assert.equal(await validatePrivateDirectory(privateFixture), await realpath(privateFixture));
  } finally {
    if (previous === undefined) delete process.env.PSModulePath;
    else process.env.PSModulePath = previous;
  }
});
test('existing or interrupted private record prevents a second register before network', async (t) => {
  const root = await directory(t); await writeFile(join(root, privateRecordName), '{incomplete');
  const f = backend(); const result = await runGlobalAuthAccountQa(options(root, f));
  assert.equal(result.passed, false); assert.equal(f.calls.length, 0);
});
test('404 read-only gate sends zero POSTs and creates no credential file', async (t) => {
  const root = await directory(t); const f = backend(() => json({code: 404, message: secret}, 404));
  const result = await runGlobalAuthAccountQa(options(root, f));
  assert.equal(result.passed, false); assert.equal(f.calls.some((c) => c.method !== 'GET'), false);
  assert.deepEqual(await readdir(root), []); publicPrivacy(result);
});
for (const registration of [{email: true, sms: false, verificationRequired: true}, {email: false, sms: true, verificationRequired: false}]) {
  test(`requires explicitly open no-code EMAIL after smoke: ${JSON.stringify(registration)}`, async (t) => {
    const root = await directory(t); const f = backend(({path}) => {
      if (path.endsWith('/auth/capabilities')) return ok({...caps(), registration});
    });
    const result = await runGlobalAuthAccountQa(options(root, f));
    assert.equal(result.passed, false); assert.equal(f.calls.some((c) => c.method === 'POST'), false);
    assert.deepEqual(await readdir(root), []);
  });
}
test('register/rotation/revocation/password login uses real fields, keeps account, logs out both sessions', async (t) => {
  const root = await directory(t); const f = backend(); const emitted = [];
  const result = await runGlobalAuthAccountQa(options(root, f, {emit: (row) => emitted.push(row)}));
  assert.equal(result.passed, true); assert.equal(f.sessions.length, 2);
  assert.equal(f.sessions.every((value) => value.revoked), true);
  const lines = (await readFile(join(root, privateRecordName), 'utf8')).trim().split('\n').map(JSON.parse);
  const credentials = lines[0];
  assert.equal(credentials.email === f.account.email && credentials.password === f.account.password, true);
  assert.equal(lines.at(-1).checks.cleanupConfirmed, true);
  assert.equal(JSON.stringify(lines).includes('fixture-access-'), false);
  assert.equal(JSON.stringify(lines).includes('fixture-refresh-'), false);
  assert.equal(JSON.stringify(lines).includes(memberId), false);
  for (const step of ['old_access_rejected', 'old_refresh_rejected', 'logged_out_access_rejected', 'logged_out_refresh_rejected']) {
    assert.equal(result.records.find((row) => row.step === step).httpStatus, 401);
  }
  publicPrivacy(result, credentials); publicPrivacy(emitted, credentials);
  const count = f.calls.length;
  assert.equal((await runGlobalAuthAccountQa(options(root, f))).passed, false);
  assert.equal(f.calls.length, count);
});
test('member mismatch aborts flow and still cleans the known session', async (t) => {
  const root = await directory(t); const f = backend(({path, token, sessions}) => {
    if (path.endsWith('/members/me') && token && sessions.some((session) => session.accessToken === token && !session.revoked)) return ok({id: secret});
  });
  const result = await runGlobalAuthAccountQa(options(root, f));
  assert.equal(result.passed, false); assert.equal(f.sessions.every((value) => value.revoked), true);
  assert.equal(result.records.at(-1).checks.cleanupConfirmed, true); publicPrivacy(result, f.account);
});
test('register timeout preserves flushed credentials and never retries registration', async (t) => {
  const root = await directory(t); const f = backend(({path}) => {
    if (path.endsWith('/auth/register')) return new Promise(() => {});
  });
  const result = await runGlobalAuthAccountQa(options(root, f, {timeoutMs: 5}));
  assert.equal(result.passed, false); assert.equal(result.records.at(-1).checks.manualRecoveryNeeded, true);
  assert.equal(f.calls.filter((c) => c.path.endsWith('/auth/register')).length, 1);
  const rows = (await readFile(join(root, privateRecordName), 'utf8')).trim().split('\n').map(JSON.parse);
  assert.equal(rows.some((row) => row.stage === 'registration_attempted'), true);
  assert.equal(rows.at(-1).checks.manualRecoveryNeeded, true); publicPrivacy(result, rows[0]);
});
test('unknown session in malformed successful registration remains explicitly recoverable', async (t) => {
  const root = await directory(t); const f = backend(({path}) => path.endsWith('/auth/register') ? ok({member: {id: memberId}}, 201) : undefined);
  const result = await runGlobalAuthAccountQa(options(root, f));
  assert.equal(result.passed, false); assert.equal(result.records.at(-1).checks.manualRecoveryNeeded, true);
  publicPrivacy(result);
});
test('refresh timeout cleans known token but never claims unknown rotated session is gone', async (t) => {
  const root = await directory(t); const f = backend(({path}) => path.endsWith('/auth/refresh') ? new Promise(() => {}) : undefined);
  const result = await runGlobalAuthAccountQa(options(root, f, {timeoutMs: 5}));
  assert.equal(result.passed, false); assert.equal(f.sessions[0].revoked, true);
  assert.equal(result.records.at(-1).checks.manualRecoveryNeeded, true);
});
test('interruption stops business requests and bounded cleanup ignores the canceled signal', async (t) => {
  const root = await directory(t); const interrupt = new AbortController();
  const f = backend(({path, token}) => {
    if (path.endsWith('/members/me') && token && !interrupt.signal.aborted) { interrupt.abort(); return new Promise(() => {}); }
  });
  const result = await runGlobalAuthAccountQa(options(root, f, {signal: interrupt.signal}));
  assert.equal(result.passed, false); assert.equal(f.sessions.every((value) => value.revoked), true);
  assert.equal(f.calls.some((c) => c.path.endsWith('/auth/login')), false);
  assert.equal(f.calls.at(-1).path.endsWith('/members/me'), true);
  assert.equal(result.records.at(-1).checks.cleanupConfirmed, true);
});
test('failed logout acknowledgement cannot become a passing flow after cleanup retry', async (t) => {
  const root = await directory(t); let attempts = 0;
  const f = backend(({path}) => path.endsWith('/auth/logout') && ++attempts === 1 ? ok({loggedOut: false}, 201) : undefined);
  const result = await runGlobalAuthAccountQa(options(root, f));
  assert.equal(result.passed, false); assert.equal(f.sessions[0].revoked, true);
  assert.equal(result.records.at(-1).checks.cleanupConfirmed, true);
});
test('cleanup itself is bounded and leaves a manual-recovery flag', async (t) => {
  const root = await directory(t); const f = backend(({path, token}) => {
    if (path.endsWith('/members/me') && token) return ok({id: secret});
    if (path.endsWith('/auth/logout')) return new Promise(() => {});
  });
  const result = await runGlobalAuthAccountQa(options(root, f, {timeoutMs: 5}));
  assert.equal(result.records.at(-1).checks.manualRecoveryNeeded, true);
});
test('register redirect is never followed and never exposes headers/body/exception values', async (t) => {
  const root = await directory(t); const f = backend(({path}) => path.endsWith('/auth/register')
    ? new Response(secret, {status: 302, headers: {Location: `https://old.example/${secret}`}}) : undefined);
  const result = await runGlobalAuthAccountQa(options(root, f));
  assert.equal(result.passed, false); assert.equal(f.calls.filter((c) => c.method === 'POST').length, 1);
  publicPrivacy(result);
});
test('a rejected old access response must not include member data', async (t) => {
  const root = await directory(t); const f = backend(({path, token, sessions}) => {
    if (path.endsWith('/members/me') && token && sessions.length
        && token !== sessions[0].accessToken) return json({code: 401, data: {id: secret}}, 401);
  });
  const result = await runGlobalAuthAccountQa(options(root, f));
  assert.equal(result.passed, false); assert.equal(f.sessions.every((value) => value.revoked), true);
  publicPrivacy(result, f.account);
});
test('unexpected old refresh session is cleaned as well and never accepted as rejection', async (t) => {
  const root = await directory(t); const f = backend(({path, body, sessions, issue}) => {
    if (path.endsWith('/auth/refresh') && sessions.length && body.refreshToken !== sessions[0].refreshToken) {
      return ok(issue(), 201);
    }
  });
  const result = await runGlobalAuthAccountQa(options(root, f));
  assert.equal(result.passed, false); assert.equal(f.sessions.length, 2);
  assert.equal(f.sessions.every((value) => value.revoked), true); publicPrivacy(result, f.account);
});

test('rotation leaving the old access valid fails and cleans both old and new sessions', async (t) => {
  const root = await directory(t); const f = backend(({path, sessions, issue}) => {
    if (path.endsWith('/auth/refresh') && sessions.length === 1) return ok(issue(), 201);
  });
  const result = await runGlobalAuthAccountQa(options(root, f));
  assert.equal(result.passed, false);
  assert.equal(result.records.find((row) => row.step === 'old_access_rejected').httpStatus, 200);
  assert.equal(f.sessions.length, 2);
  assert.equal(f.sessions.every((session) => session.revoked), true);
  for (const session of f.sessions) {
    assert.equal(f.calls.some((call) => call.path.endsWith('/auth/logout') && call.token === session.accessToken), true);
  }
  assert.equal(result.records.at(-1).checks.cleanupConfirmed, true);
  publicPrivacy(result, f.account);
});

for (const alwaysLies of [false, true]) {
  test(`logout acknowledgement without revocation fails; cleanup must read 401 (persistent=${alwaysLies})`, async (t) => {
    const root = await directory(t); let attempts = 0;
    const f = backend(({path}) => {
      if (path.endsWith('/auth/logout') && (++attempts === 1 || alwaysLies)) return ok({loggedOut: true}, 201);
    });
    const result = await runGlobalAuthAccountQa(options(root, f));
    assert.equal(result.passed, false);
    assert.equal(result.records.find((row) => row.step === 'logged_out_access_rejected').httpStatus, 200);
    assert.equal(attempts, 2);
    assert.equal(result.records.at(-1).checks.cleanupConfirmed, !alwaysLies);
    assert.equal(result.records.at(-1).checks.manualRecoveryNeeded, alwaysLies);
    assert.equal(f.sessions[0].revoked, !alwaysLies);
    publicPrivacy(result, f.account);
  });
}

test('final password-login logout also requires confirmed access revocation', async (t) => {
  const root = await directory(t); let attempts = 0;
  const f = backend(({path}) => {
    if (path.endsWith('/auth/logout') && ++attempts === 2) return ok({loggedOut: true}, 201);
  });
  const result = await runGlobalAuthAccountQa(options(root, f));
  assert.equal(result.passed, false);
  assert.equal(result.records.find((row) => row.step === 'password_login_access_rejected').httpStatus, 200);
  assert.equal(f.sessions.every((session) => session.revoked), true);
  assert.equal(result.records.at(-1).checks.cleanupConfirmed, true);
  publicPrivacy(result, f.account);
});

for (const [label, mutate] of [
  ['consent version', (capability) => { capability.consentVersion = 'unreviewed-v2'; }],
  ['agreement path', (capability) => { capability.legal.userAgreement.path = capability.legal.userAgreement.path.replace('locale=en', 'locale=fr'); }],
  ['privacy path', (capability) => { capability.legal.privacyPolicy.path = capability.legal.privacyPolicy.path.replace('locale=en', 'locale=fr'); }],
]) {
  test(`changed ${label} after reviewed smoke causes zero POSTs and no private record`, async (t) => {
    const root = await directory(t); let count = 0;
    const f = backend(({path}) => {
      if (path.endsWith('/auth/capabilities') && ++count === 2) {
        const capability = caps(); mutate(capability); return ok(capability);
      }
    });
    const result = await runGlobalAuthAccountQa(options(root, f));
    assert.equal(result.passed, false);
    assert.equal(result.records.find((row) => row.step === 'gate_summary').status, 'passed');
    assert.equal(result.records.find((row) => row.step === 'temporary_registration').status, 'failed');
    assert.equal(f.calls.some((call) => call.method === 'POST'), false);
    assert.deepEqual(await readdir(root), []);
    publicPrivacy(result);
  });
}

for (const attempt of [2, 3, 4]) {
  test(`unexpected refresh issuance without an access token requires manual recovery (attempt=${attempt})`, async (t) => {
    const root = await directory(t); let attempts = 0;
    const f = backend(({path}) => {
      if (path.endsWith('/auth/refresh') && ++attempts === attempt) return ok({refreshToken: secret}, 201);
    });
    const result = await runGlobalAuthAccountQa(options(root, f));
    assert.equal(result.passed, false);
    assert.equal(result.records.at(-1).checks.cleanupConfirmed, false);
    assert.equal(result.records.at(-1).checks.manualRecoveryNeeded, true);
    assert.equal(f.sessions.every((session) => session.revoked), true);
    publicPrivacy(result, f.account);
  });
}
