import { http } from '@kit.NetworkKit';
import { API_BASE, ApiError, Envelope, Session, FormField, decodeEnvelope, buildMultipart } from '../model/Contracts';
import { AccountClient, ApiTransport } from './AccountClient';
import { SessionVault } from './SessionVault';

class NativeHttpTransport implements ApiTransport {
  async request(path: string, fields?: FormField[], session?: Session, jsonBody?: string): Promise<Envelope> {
    // Fixed HTTPS origin; credentials never reach configurable hosts or redirects.
    if (!path.startsWith('/api/') || path.includes('://')) throw new ApiError('请求地址不正确');
    if (fields && jsonBody !== undefined) throw new ApiError('请求格式不正确');
    const client = http.createHttp();
    const headers: Record<string, string> = { 'Accept': 'application/json' };
    if (session) {
      headers['Authorization'] = `Bearer ${session.accessToken}`;
      headers['token'] = session.accessToken;
    }
    const boundary = `----SaydianHarmony${Date.now()}${Math.floor(Math.random() * 1000000)}`;
    if (fields) headers['Content-Type'] = `multipart/form-data; boundary=${boundary}`;
    if (jsonBody !== undefined) headers['Content-Type'] = 'application/json';
    try {
      const response = await client.request(`${API_BASE}${path}`, {
        method: fields || jsonBody !== undefined ? http.RequestMethod.POST : http.RequestMethod.GET,
        header: headers,
        extraData: fields ? buildMultipart(fields, boundary) : jsonBody ?? '',
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 15000,
        maxRedirects: 0,
        maxLimit: 2 * 1024 * 1024,
        usingCache: false
      });
      return decodeEnvelope(response.result as string, response.responseCode);
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError('网络连接失败或超时，请检查网络后重试');
    } finally { client.destroy(); }
  }
}

export const saydianApi: AccountClient = new AccountClient(new NativeHttpTransport(), new SessionVault());
