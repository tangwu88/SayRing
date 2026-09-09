import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const origin = 'https://app.saydian.cn';
const prefix = '/global/api/saydian-app/v2';
const canonicalPrefix = '/api/saydian-app/v2';
const locales = new Set(['en', 'zh-Hans', 'zh-Hant', 'de', 'fr', 'es', 'ja', 'ko']);
const fixedPaths = new Set([
  '/global/health/ready', `${prefix}/auth/capabilities?locale=en`, `${prefix}/members/me`,
]);
const maxBodyBytes = 256 * 1024;
const uuid = /^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$/i;
const object = (value) => value !== null && typeof value === 'object' && !Array.isArray(value);
const nonempty = (value) => typeof value === 'string' && value.trim().length > 0;
const legalTextPresent = (value) => nonempty(value) && nonempty(value
  .replace(/<!--[\s\S]*?-->/g, '')
  .replace(/<(script|style|noscript)\b[^>]*>[\s\S]*?<\/\1\s*>/gi, '')
  .replace(/<[^>]*>/g, ' ')
  .replace(/&(?:nbsp|#160|#x0*a0);/gi, ' '));

class ProbeFailure extends Error {
  constructor(status) { super(status); this.status = status; }
}

// Return a newly built, fixed-origin URL, never the server's raw reference.
export function legalSmokePath(reference, documentType, version) {
  if (!['user_agreement', 'privacy_policy'].includes(documentType)
      || !nonempty(version) || version.length > 80 || /[\x00-\x1f\x7f]/.test(version)
      || typeof reference !== 'string' || reference.length > 1024
      || /[\\#\x00-\x20\x7f]/.test(reference)) return null;
  const candidates = [canonicalPrefix, prefix].map((base) => `${base}/content/legal/${documentType}?`);
  if (!candidates.some((candidate) => reference.startsWith(candidate))) return null;
  const parsed = new URL(reference, origin);
  const query = parsed.searchParams;
  if (parsed.origin !== origin || parsed.username || parsed.password
      || [...query.keys()].some((key) => !['version', 'locale'].includes(key))
      || query.getAll('version').length !== 1 || query.get('version') !== version
      || query.getAll('locale').length !== 1 || !locales.has(query.get('locale'))) return null;
  return `${prefix}/content/legal/${documentType}?version=${encodeURIComponent(version)}&locale=${query.get('locale')}`;
}

function permittedPath(path) {
  if (fixedPaths.has(path)) return true;
  for (const type of ['user_agreement', 'privacy_policy']) {
    if (!path.startsWith(`${prefix}/content/legal/${type}?`)) continue;
    const parsed = new URL(path, origin);
    return legalSmokePath(path, type, parsed.searchParams.get('version')) === path;
  }
  return false;
}

async function jsonBody(response) {
  if (!/^application\/(?:[a-z0-9.+-]+\+)?json(?:\s*;|$)/i.test(response.headers.get('content-type') ?? '')) {
    throw new ProbeFailure('invalid_json');
  }
  if (Number(response.headers.get('content-length')) > maxBodyBytes) {
    throw new ProbeFailure('body_too_large');
  }
  const reader = response.body?.getReader();
  if (!reader) throw new ProbeFailure('invalid_json');
  const chunks = [];
  let size = 0;
  try {
    while (true) {
      const {done, value} = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > maxBodyBytes) throw new ProbeFailure('body_too_large');
      chunks.push(value);
    }
    const payload = JSON.parse(Buffer.concat(chunks).toString('utf8'));
    if (!object(payload)) throw new ProbeFailure('invalid_json');
    return payload;
  } catch (error) {
    void reader.cancel().catch(() => {});
    if (error instanceof ProbeFailure) throw error;
    throw new ProbeFailure('invalid_json');
  } finally {
    reader.releaseLock();
  }
}

async function request(path, fetchImpl, timeoutMs) {
  if (!permittedPath(path)) return {status: 'blocked_path', httpStatus: null, requestId: null};
  const controller = new AbortController();
  let httpStatus = null;
  let requestId = null;
  let timer;
  try {
    return await Promise.race([
      (async () => {
        const response = await fetchImpl(origin + path, {
          method: 'GET', redirect: 'error', credentials: 'omit',
          headers: {Accept: 'application/json', 'Accept-Language': 'en', 'Cache-Control': 'no-store'},
          signal: controller.signal,
        });
        httpStatus = response.status;
        const headerId = response.headers.get('x-request-id');
        if (typeof headerId === 'string' && uuid.test(headerId)) requestId = headerId;
        if (response.redirected || (httpStatus >= 300 && httpStatus < 400)) {
          throw new ProbeFailure('redirect_rejected');
        }
        // Native fetch cannot redirect in error mode. Also reject a substituted
        // response URL in injected transports, before touching its body.
        if (response.url && response.url !== origin + path) throw new ProbeFailure('origin_rejected');
        const payload = await jsonBody(response);
        if (typeof payload.requestId === 'string' && uuid.test(payload.requestId)) requestId = payload.requestId;
        return {status: 'received', httpStatus, requestId, payload};
      })(),
      new Promise((_, reject) => {
        timer = setTimeout(() => {
          reject(new ProbeFailure('timeout'));
          controller.abort();
        }, timeoutMs);
      }),
    ]);
  } catch (error) {
    return {status: error instanceof ProbeFailure ? error.status : 'transport_error', httpStatus, requestId};
  } finally {
    clearTimeout(timer);
    controller.abort();
  }
}

// Injection exists solely for host-side fixtures. The CLI accepts no URL,
// credentials, environment override or mutation mode.
export async function runGlobalAuthSmoke({fetchImpl = globalThis.fetch, timeoutMs = 15000} = {}) {
  if (!Number.isInteger(timeoutMs) || timeoutMs < 1 || timeoutMs > 15000) {
    throw new ProbeFailure('invalid_timeout');
  }
  const records = [];
  const record = (check, response, checks, extra = {}) => {
    const passed = response.status === 'received' && Object.values(checks).every((value) => value === true);
    records.push({
      check, status: passed ? 'passed' : response.status === 'received' ? 'failed' : response.status,
      httpStatus: response.httpStatus, requestId: response.requestId, checks, ...extra,
    });
    return passed;
  };
  const ready = await request('/global/health/ready', fetchImpl, timeoutMs);
  const readyPassed = record('readiness', ready, {
    httpOk: ready.httpStatus === 200,
    ready: ready.payload?.status === 'ready', databaseReady: ready.payload?.database === 'ok',
  });
  const caps = await request(`${prefix}/auth/capabilities?locale=en`, fetchImpl, timeoutMs);
  const data = caps.payload?.data;
  const registration = data?.registration;
  const capsPassed = record('capabilities', caps, {
    httpOk: caps.httpStatus === 200, envelopeOk: caps.payload?.code === 200,
    globalRealm: data?.realm === 'global',
    registrationContract: object(registration) && ['email', 'sms', 'verificationRequired'].every((key) => typeof registration[key] === 'boolean'),
    registrationEnabled: registration?.email === true || (registration?.sms === true
      && (registration.verificationRequired === false || (Array.isArray(data?.smsCountries)
        && data.smsCountries.some((country) => typeof country === 'string' && /^[A-Z]{2}$/.test(country))))),
    localesValid: Array.isArray(data?.supportedLocales) && data.supportedLocales.includes('en') && data.supportedLocales.every((locale) => locales.has(locale)),
    consentVersionPresent: nonempty(data?.consentVersion) && data.consentVersion.length <= 80,
  }, {realm: data?.realm === 'global' ? 'global' : data?.realm == null ? null : 'other'});
  const anonymous = await request(`${prefix}/members/me`, fetchImpl, timeoutMs);
  const anonymousPassed = record('anonymous_member', anonymous, {
    unauthorized: anonymous.httpStatus === 401,
    noMemberData: anonymous.payload?.data == null && !anonymous.payload?.member
      && !anonymous.payload?.accessToken && !anonymous.payload?.refreshToken,
  });
  let legalPassed = true;
  const legalPaths = {};
  for (const [key, type] of [['userAgreement', 'user_agreement'], ['privacyPolicy', 'privacy_policy']]) {
    const path = capsPassed ? legalSmokePath(data?.legal?.[key]?.path, type, data?.consentVersion) : null;
    if (path === null) {
      legalPassed = false;
      record(type, {status: 'blocked_reference', httpStatus: null, requestId: null}, {referenceValid: false});
      continue;
    }
    legalPaths[key] = path;
    const response = await request(path, fetchImpl, timeoutMs);
    const document = response.payload?.data;
    const passed = record(type, response, {
      referenceValid: true, httpOk: response.httpStatus === 200, envelopeOk: response.payload?.code === 200,
      documentTypeMatches: document?.documentType === type,
      versionMatches: document?.version === data.consentVersion,
      localeMatches: document?.locale === new URL(path, origin).searchParams.get('locale'),
      reviewed: document?.reviewed === true,
      contentPresent: legalTextPresent(document?.contentHtml),
    });
    legalPassed = legalPassed && passed;
  }
  const passed = readyPassed && capsPassed && anonymousPassed && legalPassed;
  records.push({check: 'summary', status: passed ? 'passed' : 'failed', checks: {
    ready: readyPassed, globalRegistration: capsPassed, anonymousDenied: anonymousPassed,
    reviewedMatchingLegal: legalPassed, readOnly: true, loginOrRegistrationTested: false,
  }});
  // Internal gate metadata only: CLI deliberately emits records, never these
  // references. A mutating caller must use the exact consent it just validated.
  const validatedLegal = passed ? {consentVersion: data.consentVersion,
    userAgreementPath: legalPaths.userAgreement, privacyPolicyPath: legalPaths.privacyPolicy} : null;
  return {passed, records, validatedLegal};
}

export async function main(args = process.argv.slice(2)) {
  if (args.length > 0) {
    console.log(JSON.stringify({check: 'cli', status: 'invalid_arguments', checks: {readOnly: true}}));
    return 2;
  }
  try {
    const result = await runGlobalAuthSmoke();
    for (const row of result.records) console.log(JSON.stringify(row));
    return result.passed ? 0 : 1;
  } catch {
    console.log(JSON.stringify({check: 'cli', status: 'failed', checks: {readOnly: true}}));
    return 1;
  }
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  process.exitCode = await main();
}
