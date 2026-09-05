import { http } from '@kit.NetworkKit';
import { ApiError } from '../model/Contracts';
import { AppUpdateInfo, parseAppUpdateManifest } from '../model/ExperienceContracts';

const UPDATE_MANIFEST_URL: string = 'https://app.saidian.cc/app-update.json';
export const HARMONY_VERSION_NAME: string = '0.1.3';
export const HARMONY_VERSION_CODE: number = 4;

export class AppUpdateService {
  async check(): Promise<AppUpdateInfo> {
    const client = http.createHttp();
    try {
      const response = await client.request(UPDATE_MANIFEST_URL, {
        method: http.RequestMethod.GET,
        header: { 'Accept': 'application/json' },
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 12000,
        readTimeout: 12000,
        maxRedirects: 0,
        maxLimit: 256 * 1024,
        usingCache: false
      });
      if (response.responseCode === 404) throw new ApiError('在线更新服务暂未配置', 404);
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new ApiError('在线更新服务暂不可用', response.responseCode);
      }
      return parseAppUpdateManifest(response.result as string, HARMONY_VERSION_CODE);
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError('暂时无法检查更新，请稍后重试');
    } finally { client.destroy(); }
  }
}

export const appUpdateService: AppUpdateService = new AppUpdateService();
