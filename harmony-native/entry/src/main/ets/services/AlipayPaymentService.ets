import { Pay } from '@cashier_alipay/cashiersdk';
import { ApiError } from '../model/Contracts';
import type { HarmonyPaymentRequest } from '../model/PushPaymentContracts';
import { withPaymentTimeout } from '../model/PaymentWatchdog';

export async function startAlipayPayment(request: HarmonyPaymentRequest): Promise<void> {
  if (request.provider !== 'alipay') throw new ApiError('支付方式不正确');
  const result = await withPaymentTimeout(new Pay().pay(request.payInfo, true));
  const status = result.get('resultStatus')?.trim() ?? '';
  if (status === '9000') return;
  if (status === '6001') throw new ApiError('已取消支付');
  if (status === '8000' || status === '6004') throw new ApiError('支付结果确认中，请稍后刷新订单');
  if (status === '6002') throw new ApiError('支付网络连接失败，请稍后重试');
  throw new ApiError('支付宝支付未完成，请确认订单后重试');
}
