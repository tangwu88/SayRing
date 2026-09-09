import { ApiError, articleBlocks, safeArticleImage } from './Contracts';
import type { ArticleBlock, FormField } from './Contracts';
import { parseAddresses, messageTime, orderStatusLabel } from './AccountPageContracts';
import type { ShippingAddress } from './AccountPageContracts';
import type { ShopOrder } from './PushPaymentContracts';

export interface ShopSku { id: number; name: string; picture: string; priceCents: number; stock: number; }
export interface ProductDetail { id: number; name: string; covers: string[]; skus: ShopSku[]; priceCents: number;
  minBuy: number; sales: string; blocks: ArticleBlock[]; }
export interface ShopLine { id: number; skuId: number; productId: number; name: string; sku: string;
  picture: string; priceCents: number; quantity: number; stock: number; applied: boolean; totalPrice: boolean; }
export interface ShopSelection { skuId: number; quantity: number; }
export interface CheckoutPreview { products: ShopLine[]; address?: ShippingAddress; productCents: number;
  shippingCents: number; pointsCents: number; }
export interface OrderDetail { order: ShopOrder; products: ShopLine[]; receiver: string; address: string;
  createdAt: string; orderCents: number; }
export interface ShipmentTrace { remark: string; time: string; }
export interface Shipment { company: string; number: string; traces: ShipmentTrace[]; }

function object(raw: Object | undefined): Record<string, Object> {
  return raw && typeof raw === 'object' && !Array.isArray(raw) ? raw as Record<string, Object> : {};
}
function text(raw: Object | undefined): string {
  return typeof raw === 'string' || typeof raw === 'number' ? String(raw).replace(/<[^>]*>/g, '').trim() : '';
}
function integer(raw: Object | undefined, fallback: number = 0): number {
  const value = text(raw); return /^-?\d+$/.test(value) && Number.isSafeInteger(Number(value)) ? Number(value) : fallback;
}
function rows(raw: Object | undefined): Object[] { return Array.isArray(raw) ? raw as Object[] : []; }

// Missing/malformed money is unknown, never a free product. All arithmetic is in cents.
export function commerceCents(raw: Object | undefined): number {
  const value = text(raw);
  if (!/^\d+(?:\.\d{1,2})?$/.test(value)) return -1;
  const parts = value.split('.'); const result = Number(parts[0]) * 100 + Number((parts[1] ?? '').padEnd(2, '0'));
  return Number.isSafeInteger(result) && result <= 10000000000 ? result : -1;
}
export function commerceMoney(cents: number): string { return cents >= 0 ? `¥${(cents / 100).toFixed(2)}` : '价格待确认'; }
export function commerceImages(raw: Object | undefined, depth: number = 0): string[] {
  if (depth > 5) return [];
  if (Array.isArray(raw)) return Array.from(new Set((raw as Object[]).flatMap((item: Object) => commerceImages(item, depth + 1)))).slice(0, 30);
  if (raw && typeof raw === 'object') {
    const row = object(raw); return commerceImages(row['url'] ?? row['picture'] ?? row['src'] ?? row['path'], depth + 1);
  }
  const value = text(raw);
  if (value.startsWith('[') || value.startsWith('{')) {
    try { return commerceImages(JSON.parse(value) as Object, depth + 1); } catch { return []; }
  }
  const url = safeArticleImage(value); return url ? [url] : [];
}
export function parseProductDetail(raw: Object | undefined, expectedId: number): ProductDetail {
  const row = object(raw), id = integer(row['id']);
  if (id !== expectedId || id <= 0 || !text(row['name'])) throw new ApiError('商品详情读取失败，请重试');
  const skus: ShopSku[] = []; const seen: Set<number> = new Set();
  rows(row['sku']).forEach((rawSku: Object) => {
    const sku = object(rawSku), skuId = integer(sku['id']);
    if (skuId > 0 && !seen.has(skuId)) {
      seen.add(skuId); skus.push({ id: skuId, name: text(sku['name']) || '默认规格',
        priceCents: commerceCents(sku['price']), stock: Math.max(-1, integer(sku['stock'], -1)),
        picture: commerceImages(sku['picture'])[0] ?? '' });
    }
  });
  let covers = commerceImages(row['covers']);
  if (!covers.length) covers = commerceImages(row['picture']);
  if (!covers.length && skus[0]?.picture) covers = [skus[0].picture];
  return { id, name: text(row['name']), covers, skus, priceCents: commerceCents(row['price']),
    minBuy: Math.max(1, Math.min(999, integer(row['min_buy'], 1))), sales: text(row['sales']),
    blocks: articleBlocks(typeof row['intro'] === 'string' ? row['intro'] as string : String(row['content'] ?? '')) };
}
export function purchaseError(product: ProductDetail | undefined, sku: ShopSku | undefined, quantity: number): string {
  if (!product || !sku || !product.skus.some((value: ShopSku) => value.id === sku.id)) return '该商品暂无可购买规格';
  if (sku.priceCents < 0 || sku.stock < 0) return '商品信息尚未完整，请刷新后重试';
  if (sku.stock === 0) return '该规格暂时缺货';
  if (!Number.isSafeInteger(quantity) || quantity < product.minBuy || quantity > Math.min(999, sku.stock)) return `请按库存选择数量，${product.minBuy} 件起购`;
  return '';
}
function line(raw: Object, cart: boolean = false): ShopLine {
  const row = object(raw), product = object(row['product']);
  return { id: integer(row['id']), skuId: integer(row['sku_id']), productId: integer(row['product_id'] ?? product['id']),
    name: text(row['product_name'] ?? product['name']) || '商品', sku: text(row['sku_name']),
    picture: commerceImages(row['product_picture'] ?? row['product_img'] ?? row['picture'] ?? product['picture'])[0] ?? '',
    priceCents: commerceCents(cart ? row['price'] ?? product['price'] : row['product_money'] ?? row['price'] ?? product['price']),
    totalPrice: !cart && row['product_money'] !== undefined,
    quantity: integer(row['number'] ?? row['quantity'] ?? row['num'], -1),
    stock: integer(row['stock'] ?? product['stock'], -1), applied: integer(row['is_customer']) === 1 };
}
export function parseCart(raw: Object | undefined): ShopLine[] {
  const row = object(raw), values = Array.isArray(raw) ? raw : row['cartList'] ?? row['list'];
  if (!Array.isArray(values)) throw new ApiError('购物车读取失败，请重试');
  const result = rows(values).map((value: Object) => line(value, true));
  const seen: Set<number> = new Set();
  for (const value of result) {
    if (value.id <= 0 || value.skuId <= 0 || value.quantity <= 0 || seen.has(value.skuId)) throw new ApiError('购物车信息不完整，请刷新');
    seen.add(value.skuId);
  }
  return result;
}
export function selectionFields(items: ShopSelection[], cart: ShopLine[] = []): FormField[] {
  const seen: Set<number> = new Set();
  if (!items.length || items.length > 100) throw new ApiError('请选择要结算的商品');
  items.forEach((item: ShopSelection) => {
    if (!Number.isSafeInteger(item.skuId) || item.skuId <= 0 || !Number.isSafeInteger(item.quantity) ||
      item.quantity <= 0 || item.quantity > 999 || seen.has(item.skuId)) throw new ApiError('商品规格或数量不正确');
    seen.add(item.skuId);
  });
  const ids: number[] = [];
  if (items.length > 1) items.forEach((item: ShopSelection) => {
    const found = cart.find((value: ShopLine) => value.skuId === item.skuId);
    if (!found || found.quantity !== item.quantity) throw new ApiError('购物车已更新，请返回刷新后重试');
    ids.push(found.id);
  });
  return [{ name: 'type', value: items.length === 1 ? 'buy_now' : 'cart' },
    { name: 'data', value: items.length === 1 ? JSON.stringify({ sku_id: items[0].skuId, num: items[0].quantity }) : ids.join(',') },
    { name: 'is_channel', value: '0' }];
}
export function parseCheckout(raw: Object | undefined): CheckoutPreview {
  const row = object(raw), summary = object(row['preview']);
  const productCents = commerceCents(summary['product_money']), shippingCents = commerceCents(summary['shipping_money']);
  const products = rows(row['products']).map((value: Object) => line(value));
  if (productCents < 0 || shippingCents < 0 || !products.length) throw new ApiError('订单金额读取失败，请重新确认');
  const address = Object.keys(object(row['address'])).length ? parseAddresses([row['address']])[0] : undefined;
  return { products, address, productCents, shippingCents, pointsCents: commerceCents(object(row['account'])['money1']) };
}
export function checkoutError(preview: CheckoutPreview | undefined, addressId: string, points: string, message: string): string {
  if (!preview) return '请先重新获取订单信息';
  if (!/^\d+$/.test(addressId) || !Number.isSafeInteger(Number(addressId)) || Number(addressId) <= 0) return '请选择收货地址';
  const cents = commerceCents(points);
  if (cents < 0 || (cents > 0 && (preview.pointsCents < 0 || cents > preview.pointsCents)) ||
    cents > preview.productCents + preview.shippingCents) return '请检查可用积分和订单金额';
  if (message.trim().length > 100) return '留言最多 100 字';
  return '';
}
export function parseOrderDetail(raw: Object | undefined, expectedId: number): OrderDetail {
  const row = object(raw), id = integer(row['id'] ?? row['order_id']);
  const status = integer(row['order_status'] ?? row['status'], -999);
  const amount = commerceCents(row['pay_money'] ?? row['order_money']);
  if (id !== expectedId || id <= 0 || status === -999 || amount < 0) throw new ApiError('订单详情读取失败，请重试');
  const products = rows(row['product'] ?? row['products']).map((value: Object) => line(value));
  return { order: { id, number: text(row['order_sn'] ?? row['order_no']) || String(id), amountCents: amount, status,
    summary: products[0]?.name ?? '赛电商城订单' }, products,
    receiver: [text(row['receiver_name'] ?? row['realname']) || '--', text(row['receiver_mobile'] ?? row['mobile']) || '--'].join('  '),
    address: [text(row['receiver_region_name']), text(row['receiver_address'] ?? row['address'])].filter((part: string) => part.length > 0).join(' ') || '--',
    createdAt: messageTime(row['created_at']) || '--', orderCents: commerceCents(row['order_money']) };
}
export function orderHeading(status: number): string {
  return status === 0 ? '等待付款' : status === 1 ? '等待发货' : status === 2 ? '等待收货' :
    status === 3 || status === 4 ? '交易完成' : orderStatusLabel(status);
}
export function orderExplanation(status: number): string {
  return status === 0 ? '请在订单有效期内完成支付' : status === 1 ? '商家正在准备您的商品' : status === 2 ?
    '商品已发出，请注意查收' : status === 3 || status === 4 ? '感谢您使用赛电商城' : '订单状态以商城最新数据为准';
}
export function parseShipments(raw: Object | undefined): Shipment[] {
  const values = object(raw)['data'];
  if (!Array.isArray(values)) throw new ApiError('物流信息暂不可用，请稍后重试');
  return rows(values).map((value: Object): Shipment => {
    const row = object(value); return { company: text(row['express_company']) || '快递', number: text(row['express_no']) || '--',
      traces: rows(row['trace']).map((trace: Object): ShipmentTrace => { const item = object(trace);
        return { remark: text(item['remark']), time: text(item['datetime']) }; }) };
  });
}
