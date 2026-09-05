import { AAID } from '@kit.PushKit';
import { notificationManager } from '@kit.NotificationKit';
import type { common } from '@kit.AbilityKit';
import type { Want } from '@kit.AbilityKit';
import { JPushInterface } from '@jg/push';
import { ApiError } from '../model/Contracts';
import type { PushIdentity } from '../model/PushPaymentContracts';

const JPUSH_APP_KEY: string = '47c3665ef1c664f3ad815112';
const JPUSH_CHANNEL: string = 'saydian_harmony';

function configureJPush(context: common.ApplicationContext): void {
  JPushInterface.setContext(context);
  JPushInterface.setAppKey(JPUSH_APP_KEY);
  JPushInterface.setChannel(JPUSH_CHANNEL);
  JPushInterface.setDebug(false);
}

export async function captureJPushClick(want: Want, context: common.ApplicationContext): Promise<void> {
  configureJPush(context);
  try { await JPushInterface.setClickWant(want, context); } catch {}
}

export class HarmonyPushService {
  private identity: PushIdentity | undefined = undefined;

  async notificationEnabled(): Promise<boolean> {
    try { return await notificationManager.isNotificationEnabled(); }
    catch (error) { throw error as Error; }
  }

  async requestNotificationPermission(context: common.UIAbilityContext): Promise<void> {
    try { await notificationManager.requestEnableNotification(context); }
    catch (error) { throw error as Error; }
  }

  async getIdentity(context: common.UIAbilityContext): Promise<PushIdentity> {
    if (this.identity) return { installationId: this.identity.installationId, registrationId: this.identity.registrationId };
    configureJPush(context.getApplicationContext());
    JPushInterface.setUserRequestNotificationPermission(context.getApplicationContext(), true);
    JPushInterface.resumePush();
    await JPushInterface.init(context);
    let installationId: string;
    try { installationId = (await AAID.getAAID()).trim(); }
    catch (error) { throw error as Error; }
    const registrationId = (await JPushInterface.getRegistrationId()).trim();
    if (!installationId || !registrationId) {
      throw new ApiError('未取得鸿蒙推送标识；请核对正式包名、Push Kit 和极光 Server key 配置');
    }
    this.identity = { installationId: installationId, registrationId: registrationId };
    return { installationId: installationId, registrationId: registrationId };
  }

  currentIdentity(): PushIdentity | undefined {
    return this.identity ? { installationId: this.identity.installationId,
      registrationId: this.identity.registrationId } : undefined;
  }

  async clearToken(): Promise<void> {
    try { JPushInterface.stopPush(); } finally { this.identity = undefined; }
  }
}

export const harmonyPush: HarmonyPushService = new HarmonyPushService();
