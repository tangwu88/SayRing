import { ApiError } from './Contracts';
export interface GlobalAnalysisDocument { path: string; locale: string; version: string; }
export interface GlobalReportProfile {
  memberId: string; consentGranted: boolean; consentVersion: string;
  availableVersion: string; document?: GlobalAnalysisDocument;
}
export interface GlobalReportEligibility {
  eligible: boolean; consentRequired: boolean; validRecordCount: number;
  distinctDays: number; minimumDistinctDays: number; availableCredits: number;
}
export const MAX_REPORT_PDF_BYTES: number = 20 * 1024 * 1024;
export function parseReportProfile(data: Object | undefined, owner: string): GlobalReportProfile {
  const value = data as Record<string, Object>, consent = value?.['analysisConsent'] as Record<string, Object>;
  if (!value || value['memberId'] !== owner || !consent || typeof consent['granted'] !== 'boolean') throw new ApiError('serviceUnavailable');
  const raw = consent['document'] as Record<string, Object>;
  const version = typeof consent['availableVersion'] === 'string' ? String(consent['availableVersion']) : '';
  let document: GlobalAnalysisDocument | undefined = undefined;
  if (raw && version && raw['version'] === version && typeof raw['locale'] === 'string' &&
    ['en','zh-Hans','zh-Hant','de','fr','es','ja','ko'].includes(String(raw['locale'])) &&
    typeof raw['path'] === 'string' && /^\/api\/saydian-app\/v2\/content\/legal\/health_ai_analysis\?[^#\\]+$/.test(String(raw['path'])) &&
    !String(raw['path']).includes('..') && !String(raw['path']).includes('://')) {
    document = { path: String(raw['path']), locale: String(raw['locale']), version };
  }
  return { memberId: owner, consentGranted: consent['granted'] === true && !!document && consent['version'] === version,
    consentVersion: typeof consent['version'] === 'string' ? String(consent['version']) : '', availableVersion: version, document };
}
export function parseReportEligibility(data: Object | undefined): GlobalReportEligibility {
  const value = data as Record<string, Object>;
  if (!value || typeof value['eligible'] !== 'boolean' || typeof value['consentRequired'] !== 'boolean') throw new ApiError('serviceUnavailable');
  for (const key of ['validRecordCount','distinctDays','minimumDistinctDays','availableCredits']) {
    if (!Number.isSafeInteger(value[key]) || Number(value[key]) < 0) throw new ApiError('serviceUnavailable');
  }
  if (Number(value['minimumDistinctDays']) < 1) throw new ApiError('serviceUnavailable');
  return { eligible: value['eligible'] === true, consentRequired: value['consentRequired'] === true,
    validRecordCount: Number(value['validRecordCount']), distinctDays: Number(value['distinctDays']),
    minimumDistinctDays: Number(value['minimumDistinctDays']), availableCredits: Number(value['availableCredits']) };
}
export function reportGenerationBlock(profile?: GlobalReportProfile, eligibility?: GlobalReportEligibility, retry: boolean = false): string {
  if (!profile || !eligibility) return 'serviceUnavailable';
  if (!profile.document || !profile.consentGranted || eligibility.consentRequired) return 'reports_consent_required';
  if (!eligibility.eligible || eligibility.validRecordCount < 1 || eligibility.distinctDays < eligibility.minimumDistinctDays) return 'reports_need_data';
  // A failed report has already acquired its entitlement. Retrying must not consume a new credit.
  if (!retry && eligibility.availableCredits < 1) return 'reports_payment_unavailable';
  return '';
}
export function validateReportPdf(bytes: ArrayBuffer): ArrayBuffer {
  if (!(bytes instanceof ArrayBuffer) || bytes.byteLength < 12 || bytes.byteLength > MAX_REPORT_PDF_BYTES) throw new ApiError('reports_export_failed');
  const view = new Uint8Array(bytes), signature = [37,80,68,70,45];
  if (!signature.every((byte, index) => view[index] === byte)) throw new ApiError('reports_export_failed');
  let tail = '';
  for (let index = Math.max(0, view.length - 1024); index < view.length; index++) tail += String.fromCharCode(view[index]);
  if (!tail.includes('%%EOF')) throw new ApiError('reports_export_failed');
  return bytes;
}
export interface GlobalHealthReport {
  id: string; status: string; from: string; to: string; validRecordCount: number;
  distinctDays: number; title: string; summary: string; aiGenerated: boolean;
}
export function globalReportId(id: string): string {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) throw new ApiError('serviceUnavailable');
  return id;
}
export function parseGlobalHealthReport(data: Object | undefined): GlobalHealthReport {
  const value = data as Record<string, Object>;
  if (!value || typeof value['id'] !== 'string' || typeof value['status'] !== 'string') throw new ApiError('serviceUnavailable');
  const period = value['period'] as Record<string, Object>, completeness = value['dataCompleteness'] as Record<string, Object>;
  if (!period || !Number.isFinite(Date.parse(String(period['from']))) || !Number.isFinite(Date.parse(String(period['to']))) ||
    !completeness || !Number.isSafeInteger(completeness['validRecordCount']) || Number(completeness['validRecordCount']) < 0 ||
    !Number.isSafeInteger(completeness['distinctDays']) || Number(completeness['distinctDays']) < 0) throw new ApiError('serviceUnavailable');
  const preview = value['freePreview'] as Record<string, Object> ?? {};
  return { id: globalReportId(String(value['id'])), status: String(value['status']),
    from: String(period['from']), to: String(period['to']),
    validRecordCount: Number(completeness['validRecordCount']), distinctDays: Number(completeness['distinctDays']),
    title: typeof preview['title'] === 'string' ? String(preview['title']) : '',
    summary: typeof preview['summary'] === 'string' ? String(preview['summary']) : '', aiGenerated: value['aiGenerated'] === true };
}
export function parseGlobalHealthReports(data: Object | undefined): GlobalHealthReport[] {
  const root = data as Record<string, Object>;
  if (!root || !Array.isArray(root['items'])) throw new ApiError('serviceUnavailable');
  return (root['items'] as Object[]).map(item => parseGlobalHealthReport(item));
}
export function parseGlobalReportContent(data: Object | undefined, expectedId: string): string[] {
  const report = parseGlobalHealthReport(data);
  if (report.id !== globalReportId(expectedId) || report.status !== 'ready') throw new ApiError('reports_pending');
  const root = data as Record<string, Object>, content = root['content'] as Record<string, Object>;
  if (!content) throw new ApiError('serviceUnavailable');
  const paragraphs: string[] = [];
  for (const key of ['overview','trends','suggestions','limitations','safetyNotice']) {
    const value = content[key];
    if (typeof value === 'string' && value.trim()) paragraphs.push(value);
    else if (Array.isArray(value)) value.forEach((item: Object) => {
      if (typeof item === 'string' && item.trim()) paragraphs.push(item);
    });
  }
  if (!paragraphs.length) throw new ApiError('serviceUnavailable');
  return paragraphs;
}
