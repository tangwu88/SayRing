import { thirdPaymentService } from '@kit.PaymentKit';
import type { common, Want } from '@kit.AbilityKit';
import type { HarmonyPaymentRequest } from '../model/PushPaymentContracts';
import { withPaymentTimeout } from '../model/PaymentWatchdog';
import { setPaymentCallbackExpected } from './PaymentLaunchState';

let activeClient: thirdPaymentService.ThirdPayClient | undefined = undefined;

export class HarmonyPaymentService {
  async start(context: common.UIAbilityContext, request: HarmonyPaymentRequest): Promise<void> {
    const method = request.provider === 'wechat' ?
      thirdPaymentService.PayMethod.WECHAT_PAY : thirdPaymentService.PayMethod.ALI_PAY;
    const client = new thirdPaymentService.ThirdPayClient(context, method, request.thirdAppId);
    activeClient = client;
    setPaymentCallbackExpected(true);
    try {
      await withPaymentTimeout(client.pay(request.payInfo));
    } finally {
      if (activeClient === client) {
        activeClient = undefined;
        setPaymentCallbackExpected(false);
      }
    }
  }
}

export function handleHarmonyPaymentCallback(want: Want): boolean {
  if (!activeClient) return false;
  try { return activeClient.handlePayCallback(want); }
  catch { return false; }
  finally {
    activeClient = undefined;
    setPaymentCallbackExpected(false);
  }
}

export const harmonyPayment: HarmonyPaymentService = new HarmonyPaymentService();
