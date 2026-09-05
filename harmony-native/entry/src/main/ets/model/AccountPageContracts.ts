import { ApiError } from './Contracts';
import type { AddressDraft } from './AddressForm';

export interface ShippingAddress { id: string; name: string; mobile: string; address: string; isDefault: boolean; draft: AddressDraft; }
export interface InboxMessage { id: number; title: string; content: string; createdAt: string; read: boolean; kind: string; }
export interface ArticleCategory { id: number; title: string; }

export function orderStatusLabel(status: number): string {
  if (status === 0) return '待支付';
  if (status === 1) return '待发货';
  if (status === 2) return '待收货';
  if (status === 3 || status === 4) return '已完成';
  if (status === -1) return '申请退款';
  if (status === -2) return '退款中';
  if (status === -3) return '已退款';
  return '订单处理中';
}

export function orderMatchesFilter(status: number, filter: number): boolean {
  return filter === 99 || (filter === -1 ? [-1, -2, -3].includes(status) :
    filter === 3 ? status === 3 || status === 4 : status === filter);
}

function rows(data: Object | undefined): Object[] {
  if (Array.isArray(data)) return data as Object[];
  if (data && typeof data === 'object') {
    const object = data as Record<string, Object>;
    if (Array.isArray(object['list'])) return object['list'] as Object[];
    if (Array.isArray(object['items'])) return object['items'] as Object[];
  }
  throw new ApiError('内容读取失败，请稍后重试');
}
function object(raw: Object): Record<string, Object> {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new ApiError('内容格式异常');
  return raw as Record<string, Object>;
}
function text(raw: Object | undefined): string {
  return typeof raw === 'string' || typeof raw === 'number' ? String(raw).replace(/<[^>]*>/g, '').trim() : '';
}

export function messageTime(raw: Object | undefined): string {
  const value = text(raw);
  if (!/^\d+(\.\d+)?$/.test(value)) return value.slice(0, 80);
  const number = Number(value);
  const date = new Date(number >= 100000000000 ? number : number * 1000);
  if (number <= 0 || !Number.isFinite(date.getTime())) return '';
  const pad = (n: number): string => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

export function parseAddresses(data: Object | undefined): ShippingAddress[] {
  return rows(data).map((raw: Object): ShippingAddress => {
    const row = object(raw);
    const id = text(row['id']);
    if (!/^\d+$/.test(id) || !Number.isSafeInteger(Number(id)) || Number(id) <= 0) throw new ApiError('地址信息不完整');
    return { id, name: text(row['realname']), mobile: text(row['mobile']),
      address: text(row['address_name'] ?? row['region']) + text(row['address_details']),
      isDefault: String(row['is_default']) === '1',
      draft: { id, name: text(row['realname']), mobile: text(row['mobile']), details: text(row['address_details']),
        isDefault: String(row['is_default']) === '1', province: text(row['province_id']),
        city: text(row['city_id']), area: text(row['area_id']) } };
  });
}

export function parseArticleCategories(data: Object | undefined): ArticleCategory[] {
  const seen: Set<number> = new Set();
  return rows(data).map((raw: Object): ArticleCategory => {
    const row = object(raw); const id = Number(row['id']);
    const title = text(row['title'] ?? row['name']).slice(0, 80);
    if (!Number.isSafeInteger(id) || id <= 0 || !title) throw new ApiError('健康分类暂时不可用');
    return { id, title };
  }).filter((row: ArticleCategory) => { if (seen.has(row.id)) return false; seen.add(row.id); return true; });
}

export function parseInbox(data: Object | undefined): InboxMessage[] {
  const seen: Set<number> = new Set();
  return rows(data).map((raw: Object): InboxMessage => {
    const row = object(raw);
    const id = Number(row['id']);
    if (!Number.isSafeInteger(id) || id <= 0) throw new ApiError('消息信息不完整');
    return { id, title: text(row['title'] ?? row['name']) || '系统消息', content: text(row['content'] ?? row['message']),
      createdAt: messageTime(row['created_at'] ?? row['createdAt']),
      read: row['is_read'] === true || row['is_read'] === 1 || row['is_read'] === '1',
      kind: text(row['kind'] ?? row['event_type']) };
  }).filter((row: InboxMessage) => { if (seen.has(row.id)) return false; seen.add(row.id); return true; });
}
