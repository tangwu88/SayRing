import { ApiError } from './Contracts';
import type { HarmonyPaymentRequest } from './PushPaymentContracts';

export interface WechatSignedPayment {
  appId: string;
  partnerId: string;
  prepayId: string;
  nonceStr: string;
  timeStamp: string;
  packageValue: string;
  sign: string;
  signType: string;
}

function field(data: Record<string, Object>, names: string[], maxLength: number = 256): string {
  for (const name of names) {
    const raw = data[name];
    if (typeof raw !== 'string' && typeof raw !== 'number') continue;
    const value = String(raw).trim();
    if (value && value.length <= maxLength && !/[\x00-\x1f\x7f]/.test(value)) return value;
  }
  return '';
}

// Only the server's explicit Harmony pay_info envelope is accepted. No signing
// or fallback to legacy Android/iOS responses is performed on the client.
export function nativeWechatPayment(request: HarmonyPaymentRequest,
  expectedAppId: string): WechatSignedPayment | undefined {
  if (request.provider !== 'wechat') return undefined;
  let data: Record<string, Object>;
  try { data = JSON.parse(request.payInfo) as Record<string, Object>; }
  catch { throw new ApiError('支付信息暂时不可用，请刷新订单后重试'); }
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    throw new ApiError('支付信息暂时不可用，请刷新订单后重试');
  }
  const prepayId = field(data, ['prepayId', 'prepayid', 'prepay_id']);
  if (!prepayId) return undefined;
  const appId = field(data, ['appId', 'appid', 'app_id']) || request.thirdAppId;
  const result: WechatSignedPayment = {
    appId: appId,
    partnerId: field(data, ['partnerId', 'partnerid', 'partner_id', 'mch_id']),
    prepayId: prepayId,
    nonceStr: field(data, ['nonceStr', 'noncestr', 'nonce_str']),
    timeStamp: field(data, ['timeStamp', 'timestamp', 'time_stamp']),
    packageValue: field(data, ['packageValue', 'package']),
    sign: field(data, ['sign', 'paySign'], 2048),
    signType: field(data, ['signType', 'sign_type'], 32)
  };
  if (appId !== expectedAppId || request.thirdAppId !== expectedAppId ||
    !result.partnerId || !result.nonceStr || !result.packageValue || !result.sign ||
    !/^\d{1,12}$/.test(result.timeStamp) || Number(result.timeStamp) <= 0) {
    throw new ApiError('支付信息暂时不可用，请刷新订单后重试');
  }
  return result;
}

export function matchesWechatPayment(prepayId: string, transaction: string,
  responsePrepayId: string, responseTransaction: string): boolean {
  if (responsePrepayId && responsePrepayId !== prepayId) return false;
  if (responseTransaction && responseTransaction !== transaction) return false;
  return responsePrepayId === prepayId || responseTransaction === transaction;
}
