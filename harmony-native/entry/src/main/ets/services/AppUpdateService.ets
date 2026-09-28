import { http } from '@kit.NetworkKit';
import { ApiError, decodeEnvelope } from '../model/Contracts';
import { AppUpdateInfo } from '../model/ExperienceContracts';
import { parseGlobalUpdate } from '../model/GlobalUpdate';
import { GLOBAL_PRODUCT, globalApiPath, internationalUrl } from '../model/GlobalConfiguration';

const UPDATE_MANIFEST_URL: string = internationalUrl(
  globalApiPath(`/support/app-update?product=${encodeURIComponent(GLOBAL_PRODUCT)}`)
);
export const HARMONY_VERSION_NAME: string = '0.1.4';
export const HARMONY_VERSION_CODE: number = 9;

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
      if (response.responseCode === 404) return { latestVersion: HARMONY_VERSION_NAME,
        latestBuild: HARMONY_VERSION_CODE, minimumSupportedBuild: 0, releaseNotes: '',
        destinationUrl: '', hasUpdate: false, required: false };
      if (response.responseCode < 200 || response.responseCode >= 300) {
        throw new ApiError('在线更新服务暂不可用', response.responseCode);
      }
      return parseGlobalUpdate(decodeEnvelope(response.result as string, response.responseCode).data, HARMONY_VERSION_CODE);
    } catch (error) {
      if (error instanceof ApiError) throw error;
      throw new ApiError('暂时无法检查更新，请稍后重试');
    } finally { client.destroy(); }
  }
}

export const appUpdateService: AppUpdateService = new AppUpdateService();
