import { common } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { preferences } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import { ApiError, decodeEnvelope } from '../model/Contracts';
import { AppDisplayState } from '../model/AppDisplay';
import type { AppDisplayCache } from '../model/AppDisplay';
import { GLOBAL_PRODUCT, globalApiPath, internationalUrl } from '../model/GlobalConfiguration';

const DISPLAY_URL: string = internationalUrl(
  globalApiPath(`/support/app-display?product=${encodeURIComponent(GLOBAL_PRODUCT)}`)
);

class DisplayCache implements AppDisplayCache {
  context: common.UIAbilityContext | undefined = undefined;

  private async store(): Promise<preferences.Preferences> {
    if (!this.context) throw new Error('Display settings are not ready');
    return preferences.getPreferences(this.context, { name: 'say_ring_global_app_display_v1' });
  }

  async read(): Promise<boolean | undefined> {
    const store = await this.store();
    const value = await store.get('hideAi', 'unknown');
    return typeof value === 'boolean' ? value : undefined;
  }

  async write(hideAi: boolean): Promise<void> {
    const store = await this.store();
    await store.put('hideAi', hideAi);
    await store.flush();
  }
}

async function readDisplay(): Promise<Object | undefined> {
  // NetworkKit redirect controls require API 23; keep API 17-22 equally strict.
  if (deviceInfo.sdkApiVersion < 23) {
    const legacy = await import('./LegacySafeHttp');
    const response = await legacy.legacySafeHttp(DISPLAY_URL, 'GET', { 'Accept': 'application/json' }, '', 12000);
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new ApiError('serviceUnavailable', response.responseCode);
    }
    return decodeEnvelope(response.result, response.responseCode).data;
  }
  const client = http.createHttp();
  try {
    const response = await client.request(DISPLAY_URL, {
      method: http.RequestMethod.GET,
      header: { 'Accept': 'application/json' },
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: 12000,
      readTimeout: 12000,
      maxRedirects: 0,
      maxLimit: 16 * 1024,
      usingCache: false
    });
    if (response.responseCode < 200 || response.responseCode >= 300) {
      throw new ApiError('serviceUnavailable', response.responseCode);
    }
    return decodeEnvelope(response.result as string, response.responseCode).data;
  } finally { client.destroy(); }
}

class AppDisplayService {
  private cache: DisplayCache = new DisplayCache();
  readonly state: AppDisplayState = new AppDisplayState(readDisplay, this.cache);
  attachContext(context: common.UIAbilityContext): void { this.cache.context = context; }
  refresh(): Promise<void> { return this.state.refresh(); }
}

export const appDisplayService: AppDisplayService = new AppDisplayService();
