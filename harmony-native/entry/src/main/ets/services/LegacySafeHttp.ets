import { rcp } from '@kit.RemoteCommunicationKit';
import { util } from '@kit.ArkTS';
import { API_BASE, ApiError } from '../model/Contracts';
import { MAX_REPORT_PDF_BYTES, validateReportPdf } from '../model/GlobalHealthReports';

export interface SafeHttpResponse { result: string; responseCode: number; }

// PDF download stays binary and uses the same redirect protection on API 17+.
export async function safeReportPdfHttp(url: string, headers: Record<string, string>): Promise<ArrayBuffer> {
  if (!new RegExp(`^${API_BASE.replace(/\./g, '\\.')}\/global\/api\/saydian-app\/v2\/health\/reports\/[0-9a-f-]{36}\/export$`, 'i').test(url)) {
    throw new ApiError('reports_export_failed');
  }
  const client = rcp.createSession({ requestConfiguration: {
    transfer: { autoRedirect: false, timeout: { connectMs: 15000, transferMs: 60000 } }
  } });
  const request = new rcp.Request(url, 'GET', headers);
  const chunks: Uint8Array[] = [];
  let total = 0, tooLarge = false;
  request.destination = (incoming: ArrayBuffer): void => {
    if (tooLarge) return;
    if (total + incoming.byteLength > MAX_REPORT_PDF_BYTES) { tooLarge = true; client.cancel(request); return; }
    chunks.push(new Uint8Array(incoming).slice()); total += incoming.byteLength;
  };
  try {
    const response = await client.fetch(request);
    if (tooLarge) throw new ApiError('reports_export_failed');
    if (response.statusCode < 200 || response.statusCode >= 300) throw new ApiError('reports_export_failed', response.statusCode);
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    return validateReportPdf(bytes.buffer);
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError('reports_export_failed');
  } finally { client.close(); }
}

// NetworkKit.maxRedirects starts at API 23. RCP has supported autoRedirect=false
// since API 11, and a bounded streaming destination since API 12.
export async function legacySafeHttp(url: string, method: 'GET' | 'POST' | 'PUT' | 'DELETE',
  headers: Record<string, string>, body: string | ArrayBuffer, readTimeout: number): Promise<SafeHttpResponse> {
  if (!url.startsWith(`${API_BASE}/global/api/`)) throw new ApiError('请求地址不正确');
  const client = rcp.createSession({ requestConfiguration: {
    transfer: { autoRedirect: false, timeout: { connectMs: 15000, transferMs: readTimeout } }
  } });
  const request = new rcp.Request(url, method, headers, body);
  const chunks: Uint8Array[] = [];
  let total = 0;
  let tooLarge = false;
  request.destination = (incoming: ArrayBuffer): void => {
    if (tooLarge) return;
    if (total + incoming.byteLength > 2 * 1024 * 1024) {
      tooLarge = true;
      client.cancel(request);
      return;
    }
    chunks.push(new Uint8Array(incoming).slice());
    total += incoming.byteLength;
  };
  try {
    const response = await client.fetch(request);
    if (tooLarge) throw new ApiError('返回的数据过多，请稍后重试');
    if (response.statusCode >= 300 && response.statusCode < 400) {
      throw new ApiError('服务地址暂不可用，请稍后重试');
    }
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
    return { result: new util.TextDecoder().decodeToString(bytes), responseCode: response.statusCode };
  } catch (error) {
    if (tooLarge) throw new ApiError('返回的数据过多，请稍后重试');
    throw error as Error;
  } finally { client.close(); }
}
