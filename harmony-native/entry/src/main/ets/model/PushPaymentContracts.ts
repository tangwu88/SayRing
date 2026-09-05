import { ApiError } from './Contracts';
import type { FormField } from './Contracts';

export type PaymentProvider = 'wechat' | 'alipay';

export interface PushIdentity {
  installationId: string;
  registrationId: string;
}

export interface ShopOrder {
  id: number;
  number: string;
  amountCents: number;
  status: number;
  summary: string;
}

export interface HarmonyPaymentRequest {
  provider: PaymentProvider;
  thirdAppId: string;
  payInfo: string;
}

function object(value: Object | undefined): Record<string, Object> {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, Object> : {};
}

function text(value: Object | undefined, maxLength: number = 512): string {
  if (typeof value !== 'string' && typeof value !== 'number') return '';
  const normalized = String(value).trim();
  return normalized.length > 0 && normalized.length <= maxLength ? normalized : '';
}

function integer(value: Object | undefined): number {
  const parsed = typeof value === 'number' ? value : Number(text(value));
  return Number.isSafeInteger(parsed) ? parsed : 0;
}

function cents(value: Object | undefined): number {
  const parsed = typeof value === 'number' ? value : Number(text(value));
  if (!Number.isFinite(parsed) || parsed <= 0 || parsed > 100000000) return 0;
  const result = Math.round(parsed * 100);
  return Number.isSafeInteger(result) && result > 0 ? result : 0;
}

function safeJson(value: Record<string, Object>): string {
  const serialized = JSON.stringify(value);
  if (serialized.length === 0 || serialized.length > 16384) throw new ApiError('支付参数长度异常');
  return serialized;
}

export function pushRegistrationFields(identity: PushIdentity, version: string): FormField[] {
  const installationId = identity.installationId.trim();
  const registrationId = identity.registrationId.trim();
  const normalizedVersion = version.trim();
  if (!/^[A-Za-z0-9._:-]{8,160}$/.test(installationId) ||
    registrationId.length < 16 || registrationId.length > 8192 || /[\r\n\0]/.test(registrationId) ||
    normalizedVersion.length === 0 || normalizedVersion.length > 64) {
    throw new ApiError('推送设备信息不完整');
  }
  return [
    { name: 'installation_id', value: installationId },
    { name: 'registration_id', value: registrationId },
    { name: 'platform', value: 'harmony' },
    { name: 'version', value: normalizedVersion }
  ];
}

export function pushErrorMessage(code: number): string {
  if (code === 1000900010) return '当前安装包与华为正式应用身份不一致';
  if (code === 1000900012) return '华为 Push Kit 尚未为当前应用开通';
  if (code === 1000900014 || code === 801) return '当前设备不支持鸿蒙推送能力';
  if (code === 1000900011) return '网络不可用，暂时无法获取推送标识';
  if (code === 1600004) return '系统通知权限未开启';
  return '推送服务暂不可用，请稍后重试';
}

export function notificationRoute(parameters: Object | undefined): string {
  const values = object(parameters);
  const event = text(values['event_type'], 80).toLowerCase();
  const route = text(values['route'], 120).toLowerCase();
  if (event === 'care_invitation' || route === 'care-invitations' || route === '/care/invitations') {
    return 'care-invitations';
  }
  if (event === 'health_alert' || route === 'health-alerts' || route === '/health/alerts') {
    return 'health-alerts';
  }
  return '';
}

export function notificationUnreadCount(data: Object | undefined): number {
  const values = object(data);
  const candidates: Object[] = [values['remind_count'], values['unread_count'], values['count']];
  for (const value of candidates) {
    const parsed = integer(value);
    if (parsed >= 0 && (parsed > 0 || String(value).trim() === '0')) return Math.min(parsed, 999);
  }
  throw new ApiError('消息未读数响应格式不正确');
}

function orderSummary(row: Record<string, Object>): string {
  const direct = text(row['product_name'] ?? row['title'] ?? row['name'], 120);
  if (direct) return direct;
  const products = row['products'];
  if (Array.isArray(products) && products.length > 0) {
    const first = object(products[0] as Object);
    const nested = text(first['product_name'] ?? first['name'] ?? first['title'], 120);
    if (nested) return nested;
  }
  return '赛电商城订单';
}

export function parseShopOrder(value: Object | undefined): ShopOrder {
  const row = object(value);
  const id = integer(row['id'] ?? row['order_id']);
  const amountCents = cents(row['pay_money'] ?? row['order_money'] ?? row['product_money']);
  const status = integer(row['order_status'] ?? row['status']);
  if (id <= 0 || !Number.isSafeInteger(id)) throw new ApiError('订单编号异常');
  if (amountCents <= 0) throw new ApiError('订单金额异常');
  return {
    id: id,
    number: text(row['order_sn'] ?? row['order_no'], 160) || String(id),
    amountCents: amountCents,
    status: status,
    summary: orderSummary(row)
  };
}

export function parseShopOrders(data: Object | undefined): ShopOrder[] {
  const root = object(data);
  const rows = Array.isArray(data) ? data as Object[] :
    Array.isArray(root['list']) ? root['list'] as Object[] :
      Array.isArray(root['items']) ? root['items'] as Object[] : [];
  const result: ShopOrder[] = [];
  const seen: Set<number> = new Set();
  rows.forEach((row: Object) => {
    try {
      const parsed = parseShopOrder(row);
      if (!seen.has(parsed.id)) { seen.add(parsed.id); result.push(parsed); }
    } catch {}
  });
  if (rows.length > 0 && result.length === 0) throw new ApiError('订单列表响应格式异常');
  return result;
}

export function paymentFields(provider: PaymentProvider, order: ShopOrder): FormField[] {
  if (order.id <= 0 || order.amountCents <= 0 || order.status !== 0) {
    throw new ApiError(order.status === 0 ? '订单金额或编号异常，请刷新后重试' : '订单状态已更新，无需重复支付');
  }
  return [
    { name: 'pay_type', value: provider === 'wechat' ? '1' : '2' },
    { name: 'jump', value: '0' },
    { name: 'trade_type', value: 'app' },
    { name: 'order_group', value: 'order' },
    { name: 'platform', value: 'harmony' },
    { name: 'data', value: JSON.stringify({ order_id: String(order.id), money: (order.amountCents / 100).toFixed(2) }) }
  ];
}

function queryValue(query: string, key: string): string {
  const match = query.match(new RegExp(`(?:^|&)${key}=([^&]+)`));
  if (!match) return '';
  try { return decodeURIComponent(match[1].replace(/\+/g, '%20')).trim(); }
  catch { return ''; }
}

function nestedCandidates(data: Object | undefined): Record<string, Object>[] {
  const root = object(data);
  const values: Record<string, Object>[] = [root];
  ['payment', 'payment_params', 'wechat', 'alipay', 'config', 'harmony'].forEach((key: string) => {
    const item = object(root[key]);
    if (Object.keys(item).length > 0) values.push(item);
  });
  return values;
}

export function parseHarmonyPayment(provider: PaymentProvider, data: Object | undefined): HarmonyPaymentRequest {
  const candidates = nestedCandidates(data);
  for (const candidate of candidates) {
    const explicitPayInfo = text(candidate['pay_info'] ?? candidate['payInfo'], 16384);
    const explicitAppId = text(candidate['third_app_id'] ?? candidate['thirdAppId'] ?? candidate['appid'] ?? candidate['app_id'], 256);
    if (explicitPayInfo && explicitAppId) {
      try {
        const parsed = JSON.parse(explicitPayInfo) as Object;
        if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) continue;
      } catch { continue; }
      return { provider: provider, thirdAppId: explicitAppId, payInfo: explicitPayInfo };
    }
  }
  if (provider === 'wechat') {
    for (const candidate of candidates) {
      const aliases: string[][] = [
        ['appid', 'app_id'], ['partnerid', 'partner_id'], ['prepayid', 'prepay_id'],
        ['package', 'package_value'], ['noncestr', 'nonce_str'], ['timestamp', 'time_stamp'], ['sign', 'signature']
      ];
      const normalized: Record<string, Object> = {};
      aliases.forEach((names: string[]) => {
        const value = text(candidate[names[0]] ?? candidate[names[1]], 4096);
        if (value) normalized[names[0]] = value;
      });
      if (Object.keys(normalized).length === aliases.length) {
        return { provider: provider, thirdAppId: String(normalized['appid']), payInfo: safeJson(normalized) };
      }
    }
  } else {
    for (const candidate of candidates) {
      const signed = text(candidate['orderInfo'] ?? candidate['order_string'] ?? candidate['orderString'] ?? candidate['config'], 16384);
      const appId = text(candidate['third_app_id'] ?? candidate['thirdAppId'], 256) || queryValue(signed, 'app_id');
      if (signed && appId) return { provider: provider, thirdAppId: appId, payInfo: safeJson({ orderInfo: signed }) };
    }
  }
  throw new ApiError(provider === 'wechat' ? '后台未返回鸿蒙微信支付参数' : '后台未返回鸿蒙支付宝支付参数');
}

export function paymentErrorMessage(code: number): string {
  if (code === 1022830000 || code === 1001930000) return '已取消支付';
  if (code === 1022830002 || code === 401) return '支付参数无效，请刷新订单后重试';
  if (code === 801) return '当前设备或系统版本不支持该支付方式';
  if (code === 1001930011) return '支付网络连接失败，请稍后重试';
  return '支付未完成，请稍后重试';
}
