import type { common, Want } from '@kit.AbilityKit';
import type { HarmonyPaymentRequest, PaymentProvider } from '../model/PushPaymentContracts';
import { ApiError } from '../model/Contracts';
import { WECHAT_APP_ID } from '../model/WechatAuthContracts';
import { nativeWechatPayment } from '../model/WechatPaymentContracts';
import { wechatPayment } from './WechatPaymentService';
import { GLOBAL_PAYMENTS_ENABLED } from '../model/GlobalConfiguration';

export function canStartHarmonyPayment(provider: PaymentProvider): boolean {
  if (!GLOBAL_PAYMENTS_ENABLED) return false;
  if (provider === 'alipay') return true;
  return (provider === 'wechat' && wechatPayment.isAvailable()) ||
    canIUse('SystemCapability.Payment.ThirdPaymentService');
}

export class HarmonyPaymentService {
  async start(context: common.UIAbilityContext, request: HarmonyPaymentRequest): Promise<void> {
    if (!GLOBAL_PAYMENTS_ENABLED) throw new ApiError('Payments are not available yet.', 503);
    if (request.provider === 'alipay') {
      const service = await import('./AlipayPaymentService');
      await service.startAlipayPayment(request);
      return;
    }
    const native = nativeWechatPayment(request, WECHAT_APP_ID);
    if (native) { await wechatPayment.start(context, native); return; }
    if (!canIUse('SystemCapability.Payment.ThirdPaymentService')) {
      throw new ApiError(request.provider === 'wechat' ?
        '支付信息暂时不可用，请稍后重试' : '当前系统暂不支持支付宝支付');
    }
    const service = await import('./ThirdPaymentService');
    await service.startThirdPayment(context, request);
  }
}

export async function handleHarmonyPaymentCallback(want: Want): Promise<boolean> {
  if (!canIUse('SystemCapability.Payment.ThirdPaymentService')) return false;
  const service = await import('./ThirdPaymentService');
  return service.handleThirdPaymentCallback(want);
}

export const harmonyPayment: HarmonyPaymentService = new HarmonyPaymentService();
