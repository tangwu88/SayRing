import { ApiError } from './Contracts';

export interface RingOrderItem { title: string; quantity: number; }
export interface RingOrderView {
  id: string; number: string; status: string; amount: number;
  currency: string; exponent: number; items: RingOrderItem[]; paymentPending: boolean;
}
function object(value: Object | undefined): Record<string, Object> {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, Object> : {};
}
function text(value: Object | undefined): string { return typeof value === 'string' ? value.trim() : ''; }
export function ringOrderId(value: string): string {
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value)) {
    throw new ApiError('请重新选择订单');
  }
  return value;
}
export function ringOrderQuery(filter: number): string {
  if (filter === 99) return '';
  if (filter === 0) return '?status=PENDING_PAYMENT';
  if (filter === 1) return '?group=pending_shipment';
  if (filter === 2) return '?status=SHIPPED';
  if (filter === 3) return '?status=COMPLETED';
  if (filter === -1) return '?group=after_sales';
  throw new ApiError('请选择订单分类');
}
export function parseRingOrder(raw: Object, capabilities?: Object, expectedId: string = ''): RingOrderView {
  const row = object(raw), checkout = object(object(capabilities)['checkout']);
  const id = ringOrderId(text(row['id']));
  if (expectedId && id !== expectedId) throw new ApiError('订单信息已变化，请重新查看');
  const amount = row['payableCents'];
  const currency = text(row['currency']) || text(checkout['currency']);
  const exponent = row['currencyExponent'] ?? (currency === text(checkout['currency']) ? checkout['currencyExponent'] : undefined);
  if (typeof amount !== 'number' || !Number.isSafeInteger(amount) || amount < 0 ||
    !/^[A-Z]{3}$/.test(currency) || typeof exponent !== 'number' || !Number.isInteger(exponent) || exponent < 0 || exponent > 4) {
    throw new ApiError('订单金额暂时无法显示，请稍后刷新');
  }
  const items: RingOrderItem[] = [];
  if (Array.isArray(row['items'])) {
    (row['items'] as Object[]).forEach((item: Object) => {
      const value = object(item), quantity = value['quantity'];
      items.push({ title: text(value['nameSnapshot']) || text(value['productName']) || text(value['title']) || '商城商品',
        quantity: typeof quantity === 'number' && Number.isSafeInteger(quantity) && quantity > 0 ? quantity : 0 });
    });
  }
  const status = text(row['status']);
  if (!status) throw new ApiError('订单状态暂时无法显示，请稍后刷新');
  const actions = row['allowedActions'];
  return { id, number: text(row['orderNo']) || id, status, amount, currency, exponent, items,
    paymentPending: status === 'PENDING_PAYMENT' && row['readOnly'] !== true && Array.isArray(actions) && actions.includes('PAY') };
}
export function ringOrderRows(raw: Object | undefined, capabilities?: Object): RingOrderView[] {
  const rows = Array.isArray(raw) ? raw : object(raw)['items'] ?? object(raw)['list'];
  if (!Array.isArray(rows)) throw new ApiError('订单暂时无法显示，请稍后刷新');
  return (rows as Object[]).map((row: Object) => parseRingOrder(row, capabilities));
}
export function ringOrderMoney(order: RingOrderView): string {
  return `${order.currency} ${(order.amount / Math.pow(10, order.exponent)).toFixed(order.exponent)}`;
}
export function ringOrderStatus(status: string): string {
  const labels: Record<string, string> = { PENDING_PAYMENT: '待付款', PAID: '待发货', PROCESSING: '待发货', WAITING_FULFILLMENT: '待发货',
    SHIPPED: '待收货', DELIVERED: '已送达', RECEIVED: '已收货', COMPLETED: '已完成', CANCELLED: '已取消', CLOSED: '已关闭',
    AFTER_SALE: '售后处理中', REFUNDING: '退款处理中', REFUNDED: '已退款' };
  return labels[status] || '请刷新查看最新状态';
}
export function sleepCustomerMessage(state: string): string {
  if (state === 'error') return '睡眠记录暂时无法更新，请稍后重试';
  if (state === 'empty') return '这段时间暂无睡眠记录，佩戴戒指入睡后，可在次日连接更新';
  return '睡眠记录用于了解日常休息情况。时长与分段以已记录的信息为准，仅供日常参考。';
}
