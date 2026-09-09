import {randomBytes} from 'node:crypto';
import {execFile} from 'node:child_process';
import {lstat, open, realpath, stat} from 'node:fs/promises';
import {dirname, isAbsolute, join, relative, resolve, sep} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {promisify} from 'node:util';
import {legalSmokePath, runGlobalAuthSmoke} from './global_auth_smoke.mjs';

const origin = 'https://app.saydian.cn';
const base = `${origin}/global/api/saydian-app/v2`;
const repository = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export const privateRecordName = 'global-auth-account-qa.jsonl';
const allowedRequests = new Set(['GET auth/capabilities?locale=en', 'GET members/me',
  'POST auth/register', 'POST auth/login', 'POST auth/refresh', 'POST auth/logout']);
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const object = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
const text = (value) => typeof value === 'string' && value.trim().length > 0;
const inside = (parent, child) => {
  const path = relative(parent, child);
  return path === '' || (!path.startsWith(`..${sep}`) && path !== '..' && !isAbsolute(path));
};
class QaFailure extends Error {
  constructor(stage) { super(stage); this.stage = stage; }
}

async function privatePermissions(directory) {
  if (process.platform !== 'win32') {
    const info = await stat(directory);
    return (info.mode & 0o077) === 0 && info.uid === process.getuid();
  }
  // Read ACL only. The operator, never this tool, grants/revokes permissions.
  const command = `$ErrorActionPreference='Stop'; $p=$env:SAYDIAN_QA_DIR_ACL_CHECK; `
    // Direct Framework API avoids inherited PowerShell 7 module paths breaking
    // Get-Acl autoload in the fixed Windows PowerShell 5.1 helper.
    + `$a=[System.IO.Directory]::GetAccessControl($p); $u=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value; `
    + `$ok=$a.AreAccessRulesProtected; foreach($r in $a.Access) { `
    + `if($r.AccessControlType -eq 'Allow') { $s=$r.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value; `
    + `if($s -notin @($u,'S-1-5-18','S-1-5-32-544')) {$ok=$false} } }; `
    + `if($ok){'private'}else{'unsafe'}`;
  const {stdout} = await promisify(execFile)(join(process.env.SystemRoot ?? 'C:\\Windows',
    'System32', 'WindowsPowerShell', 'v1.0', 'powershell.exe'),
  ['-NoProfile', '-NonInteractive', '-Command', command], {
    windowsHide: true, timeout: 5000, maxBuffer: 4096,
    env: {...process.env, SAYDIAN_QA_DIR_ACL_CHECK: directory},
  });
  return stdout.trim() === 'private';
}

export async function validatePrivateDirectory(directory, {
  repositoryDirectory = repository, permissionCheck = privatePermissions,
} = {}) {
  if (typeof directory !== 'string' || !isAbsolute(directory)) throw new QaFailure('private_directory_invalid');
  try {
    const original = await lstat(directory);
    const actual = await realpath(directory);
    const repo = await realpath(repositoryDirectory);
    if (!original.isDirectory() || original.isSymbolicLink() || dirname(actual) === actual
        || inside(repo, actual) || inside(actual, repo)) throw new QaFailure('private_directory_invalid');
    if (!await permissionCheck(actual)) throw new QaFailure('private_permissions_required');
    try {
      await lstat(join(actual, privateRecordName));
      throw new QaFailure('private_record_exists');
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    return actual;
  } catch (error) {
    if (error instanceof QaFailure) throw error;
    throw new QaFailure('private_directory_invalid');
  }
}

async function boundedJson(response) {
  if (!/^application\/(?:[a-z0-9.+-]+\+)?json(?:\s*;|$)/i.test(response.headers.get('content-type') ?? '')
      || Number(response.headers.get('content-length')) > 262144) throw new QaFailure('response_invalid');
  const reader = response.body?.getReader();
  if (!reader) throw new QaFailure('response_invalid');
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 262144) throw new QaFailure('response_invalid');
      chunks.push(value);
    }
    const result = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!object(result)) throw new QaFailure('response_invalid');
    return result;
  } catch {
    void reader.cancel().catch(() => {});
    throw new QaFailure('response_invalid');
  } finally { reader.releaseLock(); }
}

async function request(fetchImpl, method, path, {body, accessToken, signal, timeoutMs}) {
  if (!allowedRequests.has(`${method} ${path}`)) throw new QaFailure('request_blocked');
  const controller = new AbortController();
  let rejectWait;
  let timer;
  let httpStatus = null;
  let requestId = null;
  const interrupted = () => { rejectWait?.(new QaFailure('interrupted')); controller.abort(); };
  try {
    if (signal?.aborted) throw new QaFailure('interrupted');
    return await Promise.race([
      new Promise((_, reject) => {
        rejectWait = reject;
        signal?.addEventListener('abort', interrupted, {once: true});
        timer = setTimeout(() => { reject(new QaFailure('timeout')); controller.abort(); }, timeoutMs);
      }),
      (async () => {
        const response = await fetchImpl(`${base}/${path}`, {
          method, redirect: 'error', credentials: 'omit', signal: controller.signal,
          headers: {Accept: 'application/json', 'Accept-Language': 'en',
            ...(body ? {'Content-Type': 'application/json'} : {}),
            ...(accessToken ? {Authorization: `Bearer ${accessToken}`} : {})},
          ...(body ? {body: JSON.stringify(body)} : {}),
        });
        httpStatus = response.status;
        const headerId = response.headers.get('x-request-id');
        if (typeof headerId === 'string' && uuid.test(headerId)) requestId = headerId;
        if (response.redirected || (httpStatus >= 300 && httpStatus < 400)
            || (response.url && response.url !== `${base}/${path}`)) throw new QaFailure('redirect_rejected');
        const payload = await boundedJson(response);
        if (typeof payload.requestId === 'string' && uuid.test(payload.requestId)) requestId = payload.requestId;
        return {httpStatus, requestId, payload, received: true};
      })(),
    ]);
  } catch (error) {
    return {httpStatus, requestId, received: false,
      failure: error instanceof QaFailure ? error.stage : 'transport_error'};
  } finally {
    clearTimeout(timer);
    signal?.removeEventListener('abort', interrupted);
    controller.abort();
  }
}

// All network, randomness and directory checks are real in the CLI. Dependency
// injection below is solely for offline fixtures; callers must still opt in.
export async function runGlobalAuthAccountQa({
  allowIsolatedQaAccount = false, privateDirectory, fetchImpl = globalThis.fetch,
  permissionCheck = privatePermissions, repositoryDirectory = repository,
  timeoutMs = 15000, signal, emit = () => {},
} = {}) {
  const records = [];
  const output = (step, status, response = {}, checks = {}) => {
    const row = {step, status, httpStatus: response.httpStatus ?? null,
      requestId: response.requestId ?? null, checks};
    records.push(row); emit(row); return row;
  };
  let handle;
  let recordWritten = false;
  let accountMayExist = false;
  let uncertainSession = false;
  let flowPassed = false;
  const sessions = new Set();
  const journal = async (stage, checks = {}) => {
    if (!handle) return;
    await handle.writeFile(`${JSON.stringify({stage, at: new Date().toISOString(), checks})}\n`);
    await handle.sync();
  };
  const checkSignal = () => { if (signal?.aborted) throw new QaFailure('interrupted'); };
  const ok = (response) => response.received && response.httpStatus >= 200
    && response.httpStatus < 300 && response.payload?.code === 200;
  const capture = (response, step) => {
    const data = response.payload?.data;
    if (text(data?.accessToken)) sessions.add(data.accessToken);
    const valid = ok(response) && text(data?.accessToken) && text(data?.refreshToken)
      && text(data?.member?.id) && Number.isFinite(Date.parse(data?.expiresAt))
      && Date.parse(data.expiresAt) > Date.now();
    if (!valid) {
      if (!text(data?.accessToken)) uncertainSession = true;
      output(step, response.failure ?? 'failed', response, {sessionValid: false});
      throw new QaFailure('session_contract_failed');
    }
    return data;
  };
  const call = async (step, method, path, options = {}) => {
    checkSignal();
    await journal(`${step}_started`);
    const response = await request(fetchImpl, method, path, {timeoutMs, signal, ...options});
    if (!response.received && method === 'POST') uncertainSession = true;
    return response;
  };
  const assertResult = async (step, response, checks) => {
    const passed = response.received && Object.values(checks).every((value) => value === true);
    output(step, passed ? 'passed' : response.failure ?? 'failed', response, checks);
    await journal(step, {passed});
    if (!passed) throw new QaFailure('assertion_failed');
  };
  const rejectedSession = (response) => ({
    unauthorized: response.httpStatus === 401,
    noSessionData: response.payload?.data == null && !response.payload?.member
      && !response.payload?.accessToken && !response.payload?.refreshToken,
  });
  const trackUnexpectedRefresh = (response) => {
    const data = response.payload?.data;
    if (text(data?.accessToken)) sessions.add(data.accessToken);
    else if ((response.httpStatus >= 200 && response.httpStatus < 300)
        || data?.refreshToken || response.payload?.refreshToken || response.payload?.accessToken) {
      // An unexpected/malformed issuance may leave a session whose access token
      // we cannot revoke. Never claim cleanup just because the known set is empty.
      uncertainSession = true;
    }
  };
  try {
    if (allowIsolatedQaAccount !== true) throw new QaFailure('opt_in_required');
    if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 15000) throw new QaFailure('invalid_timeout');
    const directory = await validatePrivateDirectory(privateDirectory, {repositoryDirectory, permissionCheck});
    checkSignal();
    const smoke = await runGlobalAuthSmoke({fetchImpl, timeoutMs});
    for (const row of smoke.records) output(`gate_${row.check}`, row.status, row, row.checks);
    if (!smoke.passed) throw new QaFailure('read_only_gate_failed');
    const caps = await call('temporary_registration', 'GET', 'auth/capabilities?locale=en');
    const capability = caps.payload?.data;
    await assertResult('temporary_registration', caps, {
      global: ok(caps) && capability?.realm === 'global',
      emailEnabled: capability?.registration?.email === true,
      noVerification: capability?.registration?.verificationRequired === false,
      currentConsentVersion: text(capability?.consentVersion) && capability.consentVersion.length <= 80,
      validatedConsentUnchanged: capability?.consentVersion === smoke.validatedLegal?.consentVersion,
      validatedAgreementUnchanged: legalSmokePath(capability?.legal?.userAgreement?.path,
        'user_agreement', capability?.consentVersion) === smoke.validatedLegal?.userAgreementPath,
      validatedPrivacyUnchanged: legalSmokePath(capability?.legal?.privacyPolicy?.path,
        'privacy_policy', capability?.consentVersion) === smoke.validatedLegal?.privacyPolicyPath,
    });
    checkSignal();
    const email = `saydian-qa-${randomBytes(12).toString('hex')}@example.invalid`;
    const password = randomBytes(24).toString('base64url');
    // wx and a fixed filename prevent parallel/repeated creation in one private
    // directory. Credentials are flushed once, then only stage lines append.
    handle = await open(join(directory, privateRecordName), 'ax', 0o600);
    await handle.writeFile(`${JSON.stringify({kind: 'isolated_global_qa_credentials',
      createdAt: new Date().toISOString(), email, password, realm: 'global',
      consentVersion: capability.consentVersion, accountMayExist: false})}\n`);
    await handle.sync();
    recordWritten = true;
    checkSignal();
    accountMayExist = true;
    await journal('registration_attempted', {accountMayExist: true});
    const registered = await call('register', 'POST', 'auth/register', {body: {
      channel: 'email', identifier: email, password, locale: 'en', consentVersion: capability.consentVersion,
    }});
    let session = capture(registered, 'register');
    const memberId = session.member.id;
    await assertResult('register', registered, {sessionValid: true, syntheticAccount: true});
    const verifyMember = async (step, current) => {
      const response = await call(step, 'GET', 'members/me', {accessToken: current.accessToken});
      await assertResult(step, response, {httpOk: ok(response), sameMember: response.payload?.data?.id === memberId});
    };
    await verifyMember('registered_member', session);
    const original = session;
    const refreshed = await call('refresh', 'POST', 'auth/refresh', {body: {refreshToken: original.refreshToken}});
    session = capture(refreshed, 'refresh');
    await assertResult('refresh', refreshed, {sameMember: session.member.id === memberId,
      accessRotated: session.accessToken !== original.accessToken, refreshRotated: session.refreshToken !== original.refreshToken});
    await verifyMember('refreshed_member', session);
    const oldAccess = await call('old_access_rejected', 'GET', 'members/me', {accessToken: original.accessToken});
    await assertResult('old_access_rejected', oldAccess, rejectedSession(oldAccess));
    sessions.delete(original.accessToken);
    const oldRefresh = await call('old_refresh_rejected', 'POST', 'auth/refresh', {body: {refreshToken: original.refreshToken}});
    // Unexpectedly returned credentials still need cleanup before failing.
    trackUnexpectedRefresh(oldRefresh);
    await assertResult('old_refresh_rejected', oldRefresh, rejectedSession(oldRefresh));
    const logout = async (step, current) => {
      const response = await call(step, 'POST', 'auth/logout', {accessToken: current.accessToken});
      const confirmed = ok(response) && response.payload?.data?.loggedOut === true;
      await assertResult(step, response, {loggedOut: confirmed});
    };
    await logout('logout', session);
    const revoked = await call('logged_out_access_rejected', 'GET', 'members/me', {accessToken: session.accessToken});
    await assertResult('logged_out_access_rejected', revoked, rejectedSession(revoked));
    sessions.delete(session.accessToken);
    const revokedRefresh = await call('logged_out_refresh_rejected', 'POST', 'auth/refresh', {body: {refreshToken: session.refreshToken}});
    trackUnexpectedRefresh(revokedRefresh);
    await assertResult('logged_out_refresh_rejected', revokedRefresh, rejectedSession(revokedRefresh));
    const loggedIn = await call('password_login', 'POST', 'auth/login', {body: {username: email, password}});
    session = capture(loggedIn, 'password_login');
    await assertResult('password_login', loggedIn, {sameMember: session.member.id === memberId});
    await verifyMember('password_login_member', session);
    await logout('password_login_logout', session);
    const finalAccess = await call('password_login_access_rejected', 'GET', 'members/me', {accessToken: session.accessToken});
    await assertResult('password_login_access_rejected', finalAccess, rejectedSession(finalAccess));
    sessions.delete(session.accessToken);
    const finalRefresh = await call('password_login_refresh_rejected', 'POST', 'auth/refresh', {body: {refreshToken: session.refreshToken}});
    trackUnexpectedRefresh(finalRefresh);
    await assertResult('password_login_refresh_rejected', finalRefresh, rejectedSession(finalRefresh));
    flowPassed = true;
  } catch (error) {
    output('suite', error instanceof QaFailure ? error.stage : 'failed', {}, {accountMayExist, privateRecordWritten: recordWritten});
  } finally {
    // Cleanup ignores the interruption signal, but each known logout remains
    // bounded. A lost register/refresh response cannot prove all sessions closed.
    for (const accessToken of sessions) {
      const response = await request(fetchImpl, 'POST', 'auth/logout', {accessToken, timeoutMs});
      const acknowledged = ok(response) && response.payload?.data?.loggedOut === true;
      const alreadyRejected = response.received && Object.values(rejectedSession(response)).every((value) => value === true);
      const verification = await request(fetchImpl, 'GET', 'members/me', {accessToken, timeoutMs});
      const revoked = verification.received && Object.values(rejectedSession(verification)).every((value) => value === true);
      const confirmed = (acknowledged || alreadyRejected) && revoked;
      if (confirmed) sessions.delete(accessToken);
      output('cleanup_logout', acknowledged || alreadyRejected ? 'passed' : 'failed', response,
        {loggedOut: acknowledged, alreadyUnauthorized: alreadyRejected});
      output('cleanup_session', confirmed ? 'passed' : 'failed', verification, {accessRevoked: revoked, cleanupConfirmed: confirmed});
    }
    const cleanupConfirmed = sessions.size === 0 && !uncertainSession;
    const passed = flowPassed && cleanupConfirmed;
    try {
      await journal('finished', {passed, accountMayExist, cleanupConfirmed,
        manualRecoveryNeeded: accountMayExist && !cleanupConfirmed, interrupted: signal?.aborted === true});
    } catch {
      flowPassed = false;
      output('private_record', 'failed', {}, {privateRecordWritten: recordWritten});
    }
    await handle?.close().catch(() => {});
    output('summary', flowPassed && cleanupConfirmed ? 'passed' : 'partial', {}, {
      accountMayExist, privateRecordWritten: recordWritten, cleanupConfirmed,
      manualRecoveryNeeded: accountMayExist && !cleanupConfirmed, loginFlowPassed: flowPassed,
    });
  }
  return {passed: records.at(-1).status === 'passed', records};
}

export async function main(args = process.argv.slice(2)) {
  if (args.length !== 3 || args[0] !== '--allow-isolated-qa-account' || args[1] !== '--private-dir') {
    console.log(JSON.stringify({step: 'cli', status: 'opt_in_arguments_required', checks: {authorized: false}}));
    return 2;
  }
  const interrupt = new AbortController();
  const onInterrupt = () => interrupt.abort();
  process.on('SIGINT', onInterrupt);
  process.on('SIGTERM', onInterrupt);
  try {
    const result = await runGlobalAuthAccountQa({allowIsolatedQaAccount: true, privateDirectory: args[2],
      signal: interrupt.signal, emit: (row) => console.log(JSON.stringify(row))});
    return result.passed ? 0 : 1;
  } catch {
    console.log(JSON.stringify({step: 'cli', status: 'failed', checks: {authorized: true}}));
    return 1;
  } finally {
    process.removeListener('SIGINT', onInterrupt);
    process.removeListener('SIGTERM', onInterrupt);
  }
}
if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) process.exitCode = await main();
