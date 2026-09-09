import { API_BASE, ApiError } from './Contracts';

export interface AiChatMessage {
  id: string;
  text: string;
  mine: boolean;
  sessionId: string;
  failed: boolean;
}

export const AI_USER_MESSAGE_MAX_LENGTH: number = 160;
export const AI_CONCISE_RETRY_PREFIX: string = '请用不超过100个汉字简短回答：';

export function aiConciseRetryMessage(message: string): string {
  return `${AI_CONCISE_RETRY_PREFIX}${message.trim().slice(0, AI_USER_MESSAGE_MAX_LENGTH)}`;
}

export interface ShopProduct {
  id: number;
  name: string;
  picture: string;
  price: string;
  stock: number;
}

export interface ShopCategory {
  id: string;
  name: string;
  products: ShopProduct[];
}

export interface ShopHome {
  bannerUrl: string;
  categories: ShopCategory[];
}

export interface AppUpdateInfo {
  latestVersion: string;
  latestBuild: number;
  minimumSupportedBuild: number;
  releaseNotes: string;
  destinationUrl: string;
  hasUpdate: boolean;
  required: boolean;
}

function object(value: Object | undefined): Record<string, Object> {
  return value && typeof value === 'object' && !Array.isArray(value) ? value as Record<string, Object> : {};
}

function text(value: Object | undefined, maxLength: number = 512): string {
  if (typeof value !== 'string' && typeof value !== 'number') return '';
  const normalized = String(value).replace(/[\x00-\x1f\x7f]/g, '').trim();
  return normalized.length > 0 && normalized.length <= maxLength ? normalized : '';
}

function integer(value: Object | undefined): number {
  const parsed = typeof value === 'number' ? value : Number(text(value, 24));
  return Number.isSafeInteger(parsed) ? parsed : 0;
}

function list(value: Object | undefined): Object[] {
  if (Array.isArray(value)) return value as Object[];
  const root = object(value);
  if (Array.isArray(root['list'])) return root['list'] as Object[];
  if (Array.isArray(root['items'])) return root['items'] as Object[];
  return [];
}

export function safeSaydianAsset(value: Object | undefined): string {
  const source = text(value, 2048);
  if (!source) return '';
  const absolute = source.startsWith('/') ? `${API_BASE}${source}` : source;
  if (!/^https:\/\/app\.saidian\.cc\/attachment\/[A-Za-z0-9_./%+-]+(?:\?[A-Za-z0-9_=&%+.-]+)?$/.test(absolute) ||
    absolute.includes('..')) return '';
  return absolute;
}

function parseProduct(value: Object | undefined): ShopProduct | undefined {
  const row = object(value);
  const id = integer(row['id']);
  const name = text(row['name'] ?? row['product_name'], 160);
  const rawPrice = text(row['price'] ?? row['product_money'], 32);
  const priceValue = Number(rawPrice);
  if (id <= 0 || !name || !Number.isFinite(priceValue) || priceValue < 0 || priceValue > 100000000) return undefined;
  return {
    id: id,
    name: name,
    picture: safeSaydianAsset(row['picture'] ?? row['product_picture']),
    price: priceValue.toFixed(2),
    stock: Math.max(0, integer(row['stock']))
  };
}

export function parseShopHome(data: Object | undefined): ShopHome {
  const root = object(data);
  const items = list(root['items']);
  let bannerUrl = '';
  let tabRows: Object[] = [];
  items.forEach((raw: Object) => {
    const item = object(raw);
    const type = text(item['type'], 40);
    if (type === 'swiper' && !bannerUrl) {
      const banners = list(object(item['data'])['list']);
      if (banners.length > 0) bannerUrl = safeSaydianAsset(object(banners[0])['url']);
    }
    if (type === 'tabs' && Array.isArray(item['value'])) tabRows = item['value'] as Object[];
  });
  const categories: ShopCategory[] = [];
  tabRows.forEach((raw: Object, categoryIndex: number) => {
    const row = object(raw);
    const name = text(row['name'], 80) || `分类 ${categoryIndex + 1}`;
    const products: ShopProduct[] = [];
    const seen: Set<number> = new Set();
    list(row['list']).forEach((productValue: Object) => {
      const product = parseProduct(productValue);
      if (product && !seen.has(product.id)) { seen.add(product.id); products.push(product); }
    });
    categories.push({ id: `${categoryIndex}-${name}`, name: name, products: products });
  });
  if (items.length > 0 && categories.length === 0) throw new ApiError('商城首页格式异常，请稍后重试');
  return { bannerUrl: bannerUrl, categories: categories };
}

function parseAiRow(value: Object | undefined, index: number): AiChatMessage | undefined {
  const row = object(value);
  const rawMessage = text(row['message'] ?? row['content'], 12000);
  if (!rawMessage) return undefined;
  const mineValue = row['my'];
  const mine = mineValue === true || String(mineValue ?? '').trim() === '1' ||
    text(row['role'], 20).toLowerCase() === 'user';
  const message = mine && rawMessage.startsWith(AI_CONCISE_RETRY_PREFIX) ?
    rawMessage.slice(AI_CONCISE_RETRY_PREFIX.length).trim() : rawMessage;
  const sessionId = text(row['session_id'] ?? row['sessionId'], 160);
  const id = text(row['id'], 80) || `${sessionId || 'message'}-${index}`;
  return { id: id, text: message, mine: mine, sessionId: sessionId, failed: false };
}

export function parseAiMessages(data: Object | undefined): AiChatMessage[] {
  const rows = list(data);
  const messages: AiChatMessage[] = [];
  rows.forEach((row: Object, index: number) => {
    const parsed = parseAiRow(row, index);
    if (parsed) messages.push(parsed);
  });
  if (rows.length > 0 && messages.length === 0) throw new ApiError('AI 对话记录格式异常');
  return messages.reverse();
}

export function parseAiReply(data: Object | undefined): AiChatMessage {
  const parsed = parseAiRow(data, Date.now());
  if (!parsed) throw new ApiError('AI 暂未返回有效内容');
  parsed.mine = false;
  return parsed;
}

export function parseAppUpdateManifest(body: string, currentBuild: number): AppUpdateInfo {
  let root: Record<string, Object>;
  try { root = object(JSON.parse(body) as Object); }
  catch { throw new ApiError('更新信息暂时不可用，请稍后重试'); }
  const schema = integer(root['schema_version']);
  const platform = text(root['platform'], 40).toLowerCase();
  const channel = text(root['channel'], 40).toLowerCase();
  const latestVersion = text(root['latest_version'], 64);
  const latestBuild = integer(root['latest_build']);
  const minimumSupportedBuild = integer(root['minimum_supported_build']);
  const destination = object(root['destination']);
  const destinationType = text(destination['type'], 80).toLowerCase();
  const destinationUrl = text(destination['url'], 2048);
  if (schema !== 1 || platform !== 'harmony' || channel !== 'production' || !latestVersion ||
    latestBuild <= 0 || minimumSupportedBuild <= 0 || minimumSupportedBuild > latestBuild ||
    destinationType !== 'harmony_appgallery') {
    throw new ApiError('更新信息暂时不可用，请稍后重试');
  }
  if (!/^https:\/\/appgallery\.huawei\.com\/[A-Za-z0-9_./?=&%+:-]+$/.test(destinationUrl) ||
    destinationUrl.includes('..')) throw new ApiError('在线更新地址不安全');
  return {
    latestVersion: latestVersion,
    latestBuild: latestBuild,
    minimumSupportedBuild: minimumSupportedBuild,
    releaseNotes: text(root['release_notes'], 4000),
    destinationUrl: destinationUrl,
    hasUpdate: currentBuild < latestBuild,
    required: currentBuild < minimumSupportedBuild
  };
}
