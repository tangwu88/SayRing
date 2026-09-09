import { http } from '@kit.NetworkKit';
import { fileIo } from '@kit.CoreFileKit';
import { util } from '@kit.ArkTS';
import { deviceInfo } from '@kit.BasicServicesKit';
import { API_BASE, ApiError, Envelope, Session, FormField, UploadFile, decodeEnvelope, buildMultipart } from '../model/Contracts';
import { AccountClient, ApiTransport } from './AccountClient';
import { SessionVault } from './SessionVault';
import { apiReadTimeout } from '../model/RequestPolicy';

interface ImageKind { mime: string; extension: string; }

class NativeHttpTransport implements ApiTransport {
  async request(path: string, fields?: FormField[], session?: Session, jsonBody?: string,
    method?: 'GET' | 'POST' | 'PUT' | 'DELETE', readTimeoutMs?: number): Promise<Envelope> {
    // Fixed HTTPS origin; credentials never reach configurable hosts or redirects.
    if (!path.startsWith('/api/') || path.includes('://')) throw new ApiError('请求地址不正确');
    if (fields && jsonBody !== undefined) throw new ApiError('请求格式不正确');
    const requestMethod = method ?? (fields || jsonBody !== undefined ? 'POST' : 'GET');
    const timeoutMs = apiReadTimeout(readTimeoutMs);
    if ((requestMethod === 'GET' || requestMethod === 'DELETE') && (fields || jsonBody !== undefined)) {
      throw new ApiError('请求格式不正确');
    }
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
      if (deviceInfo.sdkApiVersion < 23) {
        const legacy = await import('./LegacySafeHttp');
        const response = await legacy.legacySafeHttp(`${API_BASE}${path}`, requestMethod, headers,
          fields ? buildMultipart(fields, boundary) : jsonBody ?? '', timeoutMs);
        return decodeEnvelope(response.result, response.responseCode);
      }
      const response = await client.request(`${API_BASE}${path}`, {
        method: requestMethod === 'DELETE' ? http.RequestMethod.DELETE :
          requestMethod === 'PUT' ? http.RequestMethod.PUT :
          requestMethod === 'POST' ? http.RequestMethod.POST : http.RequestMethod.GET,
        header: headers,
        extraData: fields ? buildMultipart(fields, boundary) : jsonBody ?? '',
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: timeoutMs,
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

  async upload(path: string, file: UploadFile, session: Session): Promise<Envelope> {
    if (path !== '/api/v1/file/images' || !file.uri.trim()) throw new ApiError('请求地址不正确');
    const opened = fileIo.openSync(file.uri, fileIo.OpenMode.READ_ONLY);
    let bytes: Uint8Array;
    try {
      const size = fileIo.statSync(opened.fd).size;
      if (!Number.isSafeInteger(size) || size <= 0) throw new ApiError('所选图片不可用');
      if (size > file.maxBytes) throw new ApiError('图片过大，请选择 6 MB 以内的照片');
      bytes = new Uint8Array(size);
      let offset = 0;
      while (offset < size) {
        const count = fileIo.readSync(opened.fd, bytes.buffer, { offset: offset, length: size - offset });
        if (count <= 0) break;
        offset += count;
      }
      if (offset !== size) throw new ApiError('照片读取不完整，请重新选择');
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError('无法读取照片，请重新选择');
    } finally { fileIo.closeSync(opened); }

    const kind = this.imageKind(bytes);
    if (!kind.mime) throw new ApiError('请选择 JPG、PNG、WebP 或 HEIC 图片');
    const boundary = `----SaydianHarmonyImage${Date.now()}${Math.floor(Math.random() * 1000000)}`;
    const safeStem = file.fileName.replace(/[^A-Za-z0-9_-]/g, '').slice(0, 40) || 'avatar';
    const prefix = new util.TextEncoder().encodeInto(`--${boundary}\r\n` +
      `Content-Disposition: form-data; name="file"; filename="${safeStem}.${kind.extension}"\r\n` +
      `Content-Type: ${kind.mime}\r\n\r\n`);
    const suffix = new util.TextEncoder().encodeInto(`\r\n--${boundary}--\r\n`);
    const body = new Uint8Array(prefix.length + bytes.length + suffix.length);
    body.set(prefix, 0); body.set(bytes, prefix.length); body.set(suffix, prefix.length + bytes.length);
    const client = http.createHttp();
    try {
      if (deviceInfo.sdkApiVersion < 23) {
        const legacy = await import('./LegacySafeHttp');
        const response = await legacy.legacySafeHttp(`${API_BASE}${path}`, 'POST', {
          'Accept': 'application/json', 'Authorization': `Bearer ${session.accessToken}`,
          'token': session.accessToken, 'Content-Type': `multipart/form-data; boundary=${boundary}`
        }, body.buffer, 30000);
        return decodeEnvelope(response.result, response.responseCode);
      }
      const response = await client.request(`${API_BASE}${path}`, {
        method: http.RequestMethod.POST,
        header: { 'Accept': 'application/json', 'Authorization': `Bearer ${session.accessToken}`,
          'token': session.accessToken, 'Content-Type': `multipart/form-data; boundary=${boundary}` },
        extraData: body.buffer,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 30000,
        maxRedirects: 0,
        maxLimit: 2 * 1024 * 1024,
        usingCache: false
      });
      return decodeEnvelope(response.result as string, response.responseCode);
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError('头像上传失败，请检查网络后重试');
    } finally { client.destroy(); }
  }

  private imageKind(bytes: Uint8Array): ImageKind {
    if (bytes.length >= 3 && bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) {
      return { mime: 'image/jpeg', extension: 'jpg' };
    }
    if (bytes.length >= 8 && bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47) {
      return { mime: 'image/png', extension: 'png' };
    }
    if (bytes.length >= 12 && bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
      bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50) {
      return { mime: 'image/webp', extension: 'webp' };
    }
    if (bytes.length >= 12 && bytes[4] === 0x66 && bytes[5] === 0x74 && bytes[6] === 0x79 && bytes[7] === 0x70) {
      return { mime: 'image/heic', extension: 'heic' };
    }
    return { mime: '', extension: '' };
  }
}

export const saydianApi: AccountClient = new AccountClient(new NativeHttpTransport(), new SessionVault());
