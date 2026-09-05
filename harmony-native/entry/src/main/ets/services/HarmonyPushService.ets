import { AAID } from '@kit.PushKit';
import { notificationManager } from '@kit.NotificationKit';
import type { common } from '@kit.AbilityKit';
import type { Want } from '@kit.AbilityKit';
import { CallBackMsg, JPushInterface } from '@jg/push';
import { ApiError } from '../model/Contracts';
import type { PushIdentity } from '../model/PushPaymentContracts';

const JPUSH_APP_KEY: string = '47c3665ef1c664f3ad815112';
const JPUSH_CHANNEL: string = 'saydian_harmony';
const REGISTRATION_TIMEOUT_MS: number = 15000;
const REGISTRATION_RETRY_MS: number = 500;

let registrationIdFromCallback: string = '';
let callbackConfigured: boolean = false;
let initializationTask: Promise<void> | undefined = undefined;

class SaydianPushCallback extends CallBackMsg {
  onRegister(registrationId: string): void {
    registrationIdFromCallback = registrationId.trim();
  }
}

function configureJPush(context: common.ApplicationContext): void {
  JPushInterface.setContext(context);
  JPushInterface.setAppKey(JPUSH_APP_KEY);
  JPushInterface.setChannel(JPUSH_CHANNEL);
  JPushInterface.setDebug(false);
  if (!callbackConfigured) {
    JPushInterface.setCallBackMsg(new SaydianPushCallback());
    callbackConfigured = true;
  }
}

function initializeJPush(context: common.UIAbilityContext | common.AbilityStageContext): Promise<void> {
  if (!initializationTask) {
    initializationTask = Promise.resolve(JPushInterface.init(context)).then((): void => {});
  }
  return initializationTask;
}

export function prepareJPush(context: common.AbilityStageContext): void {
  configureJPush(context.getApplicationContext());
  // The HarmonyOS SDK requires initialization from AbilityStage after the
  // callback, app key and channel have been configured.
  initializeJPush(context).catch((): void => {
    initializationTask = undefined;
  });
}

export async function captureJPushClick(want: Want, context: common.ApplicationContext): Promise<void> {
  configureJPush(context);
  try { await JPushInterface.setClickWant(want, context); } catch {}
}

export class HarmonyPushService {
  private identity: PushIdentity | undefined = undefined;

  private delay(milliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => setTimeout(resolve, milliseconds));
  }

  private async waitForRegistrationId(): Promise<string> {
    const deadline = Date.now() + REGISTRATION_TIMEOUT_MS;
    while (Date.now() < deadline) {
      const cached = registrationIdFromCallback.trim();
      if (cached) return cached;
      const current = (await JPushInterface.getRegistrationId()).trim();
      if (current) return current;
      await this.delay(REGISTRATION_RETRY_MS);
    }
    return '';
  }

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
    const applicationContext = context.getApplicationContext();
    configureJPush(applicationContext);
    JPushInterface.setUserRequestNotificationPermission(applicationContext, true);
    await initializeJPush(context);
    JPushInterface.resumePush();
    let installationId: string;
    try { installationId = (await AAID.getAAID()).trim(); }
    catch (error) { throw error as Error; }
    const registrationId = await this.waitForRegistrationId();
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
    try { JPushInterface.stopPush(); } finally {
      this.identity = undefined;
      registrationIdFromCallback = '';
    }
  }
}

export const harmonyPush: HarmonyPushService = new HarmonyPushService();
