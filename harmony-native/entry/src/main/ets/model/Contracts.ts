// Shared by ArkTS and host-side tests. No platform APIs or personal fixtures.
export const API_BASE = 'https://app.saydian.cn';

export interface Envelope {
  code?: number | string;
  message?: string;
  data?: Object;
}

export interface MemberProfile {
  id?: number | string;
  nickname?: string;
  username?: string;
  mobile?: string;
  head_portrait?: string;
  gender?: number | string;
  birthday?: string;
  height?: number | string;
  weight?: number | string;
}

export interface AuthenticationData {
  access_token?: string;
  refresh_token?: string;
  expiration_time?: number | string;
  member?: MemberProfile;
}

export interface Session {
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
  memberId: string;
  displayName: string;
}

export interface Article {
  id?: number | string;
  title?: string;
  content?: string;
  description?: string;
}

export interface ArticleBlock { id: string; kind: string; text: string; url: string; }

export interface ArticleCollection { list?: Article[]; }
export interface FormField { name: string; value: string; }
export interface UploadFile { uri: string; fileName: string; maxBytes: number; }

export class ApiError extends Error {
  status: number;
  constructor(message: string, status: number = 0) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
  }
}

export function loginValidation(account: string, password: string, accepted: boolean): string {
  if (!accepted) return '请先阅读并同意用户协议与隐私政策';
  if (account.trim().length === 0) return '请输入手机号或账号';
  if (account.trim().length > 128) return '账号长度不正确';
  if (password.length === 0) return '请输入密码';
  if (password.length > 256) return '密码长度不正确';
  return '';
}

export function registrationValidation(mobile: string, code: string, password: string,
  confirmation: string, accepted: boolean): string {
  if (!accepted) return '请先阅读并同意用户协议与隐私政策';
  if (!/^1\d{10}$/.test(mobile.trim())) return '请输入正确的中国大陆手机号';
  if (!/^\d{4,6}$/.test(code.trim())) return '请输入收到的短信验证码';
  if (password.length < 6) return '密码至少需要 6 位';
  if (password.length > 256) return '密码长度不正确';
  if (password !== confirmation) return '两次输入的密码不一致';
  return '';
}

export function wechatAuthorizationValidation(code: string, state: string): string {
  const normalizedCode = code.trim();
  const normalizedState = state.trim();
  if (normalizedCode.length < 6 || normalizedCode.length > 1024 || /[\s\x00-\x1f\x7f]/.test(normalizedCode)) {
    return '微信授权信息无效，请重试';
  }
  if (!/^sd_[0-9]{13}_[A-Za-z0-9-]{16,64}$/.test(normalizedState)) {
    return '微信授权状态已失效，请重试';
  }
  return '';
}

export function wechatOpenIdValidation(openId: string): string {
  const normalized = openId.trim();
  if (normalized.length < 6 || normalized.length > 128 || /[\s\x00-\x1f\x7f]/.test(normalized)) {
    return '微信用户标识无效，请重新授权';
  }
  return '';
}

export function canSubmitLogin(busy: boolean, restoring: boolean): boolean {
  return !busy && !restoring;
}

export function safeMessage(message: string | undefined, fallback: string): string {
  if (typeof message !== 'string') return fallback;
  const value = message.trim();
  if (!value || value.length > 160 || /<[^>]*>|trace|exception|\/var\/|\/www\/|access_token/i.test(value)) {
    return fallback;
  }
  return value;
}

export function decodeEnvelope(body: string, status: number): Envelope {
  let payload: Envelope;
  try { payload = JSON.parse(body) as Envelope; }
  catch { throw new ApiError('服务器返回格式异常，请稍后重试', status); }
  if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
    throw new ApiError('服务器返回格式异常，请稍后重试', status);
  }
  const code = payload.code === undefined ? status : Number(payload.code);
  if (status < 200 || status >= 300 || code < 200 || code >= 300) {
    const businessStatus = status < 200 || status >= 300 ? status :
      code >= 400 && code < 600 ? code : status;
    const fallback = businessStatus === 401 ? '登录已失效，请重新登录' :
      businessStatus >= 500 ? '服务暂不可用，请稍后重试' : '请求失败，请检查后重试';
    throw new ApiError(businessStatus >= 500 ? fallback : safeMessage(payload.message, fallback), businessStatus);
  }
  return payload;
}

export function expirationMillis(raw: number | string | undefined, now: number): number {
  const value = raw === undefined ? 43200 : Number(raw);
  if (!Number.isFinite(value) || value <= 0) throw new ApiError('登录凭证有效期异常');
  if (value > 1000000000000) return value;
  if (value > 1000000000) return value * 1000;
  return now + value * 1000;
}

export function parseSession(payload: Envelope, now: number, previous?: Session): Session {
  const data = payload.data as AuthenticationData;
  if (!data || typeof data !== 'object' || typeof data.access_token !== 'string' || !data.access_token.trim()) {
    throw new ApiError('登录响应缺少有效凭证，请稍后重试');
  }
  const member = data.member;
  const memberId = member && member.id !== undefined ? stableIdentity(member.id) : previous?.memberId ?? '';
  if (!memberId) throw new ApiError('登录响应缺少有效账号身份，请重新登录', 401);
  if (previous && memberId !== previous.memberId) throw new ApiError('账号状态发生变化，请重新登录', 401);
  const expiresAt = expirationMillis(data.expiration_time, now);
  if (expiresAt <= now) throw new ApiError('登录凭证已过期，请重新登录', 401);
  return validateStoredSession({
    accessToken: data.access_token.trim(),
    refreshToken: typeof data.refresh_token === 'string' ? data.refresh_token : previous?.refreshToken ?? '',
    expiresAt: expiresAt,
    memberId: memberId,
    displayName: profileName(member) || previous?.displayName || 'Say Ring 用户'
  });
}

export function stableIdentity(value: number | string | undefined): string {
  if (typeof value !== 'string' && typeof value !== 'number') return '';
  if (typeof value === 'number' && (!Number.isSafeInteger(value) || value <= 0)) return '';
  const id = String(value).trim();
  return id.length > 0 && id.length <= 128 && !/[\s\x00-\x1f\x7f]/.test(id) ? id : '';
}

export function validateStoredSession(session: Session): Session {
  if (!session || typeof session !== 'object' || Array.isArray(session) ||
    typeof session.accessToken !== 'string' || !session.accessToken || session.accessToken.length > 8192 ||
    /[\s\x00-\x1f\x7f]/.test(session.accessToken) ||
    typeof session.refreshToken !== 'string' || session.refreshToken.length > 8192 ||
    /[\s\x00-\x1f\x7f]/.test(session.refreshToken) ||
    !stableIdentity(session.memberId) || typeof session.displayName !== 'string' ||
    typeof session.expiresAt !== 'number' || !Number.isFinite(session.expiresAt) || session.expiresAt <= 0) {
    throw new ApiError('本机登录信息不可用，请重新登录', 401);
  }
  return { accessToken: session.accessToken, refreshToken: session.refreshToken,
    expiresAt: session.expiresAt, memberId: stableIdentity(session.memberId),
    displayName: session.displayName.slice(0, 128) };
}

export function parseProfile(data: Object | undefined, memberId: string): MemberProfile {
  const profile = data as MemberProfile;
  if (!profile || typeof profile !== 'object' || Array.isArray(profile)) {
    throw new ApiError('个人资料响应格式异常');
  }
  if (!stableIdentity(profile.id) || stableIdentity(profile.id) !== memberId) {
    throw new ApiError('账号资料不匹配，请重新登录', 401);
  }
  return profile;
}

export function profileName(profile?: MemberProfile): string {
  if (!profile || typeof profile !== 'object') return '';
  const nickname = typeof profile.nickname === 'string' ? profile.nickname.trim() : '';
  if (nickname && !/[\x00-\x1f\x7f]/.test(nickname)) return nickname;
  const username = typeof profile.username === 'string' ? profile.username.trim() : '';
  return username && !/[\x00-\x1f\x7f]/.test(username) ? username : '';
}

export function profileField(value: number | string | undefined, suffix: string = ''): string {
  if (value === undefined || value === '' || value === null) return '未填写';
  if (typeof value !== 'string' && typeof value !== 'number') return '未填写';
  if (typeof value === 'number' && !Number.isFinite(value)) return '未填写';
  const text = String(value).trim();
  if (!text || /^(nan|[+-]?infinity)$/i.test(text)) return '未填写';
  return `${text}${suffix}`;
}

export function parseArticles(data: Object | undefined): Article[] {
  const collection = data as ArticleCollection;
  const values = Array.isArray(data) ? data as Article[] : collection?.list;
  if (!Array.isArray(values)) throw new ApiError('健康百科列表格式异常，请重试');
  const seen: Set<string> = new Set();
  const result: Article[] = [];
  values.forEach((item: Article) => {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return;
    const id = stableIdentity(item.id);
    if (!/^\d+$/.test(id) || seen.has(id) || typeof item.title !== 'string' || !item.title.trim()) return;
    seen.add(id);
    result.push({ id: id, title: item.title.trim().slice(0, 240) });
  });
  if (values.length > 0 && result.length === 0) throw new ApiError('健康百科内容不可用，请重试');
  return result;
}

export function parseArticle(data: Object | undefined): Article {
  const article = data as Article;
  if (!article || typeof article !== 'object' || Array.isArray(article)) throw new ApiError('内容暂不可用');
  return { id: stableIdentity(article.id),
    title: typeof article.title === 'string' ? article.title.slice(0, 240) : '',
    content: typeof article.content === 'string' ? article.content : '',
    description: typeof article.description === 'string' ? article.description : '' };
}

export function buildMultipart(fields: FormField[], boundary: string): string {
  if (!/^[A-Za-z0-9-]{8,80}$/.test(boundary)) throw new ApiError('请求格式异常');
  return fields.map((field: FormField) => {
    if (!/^[a-z_]+$/.test(field.name)) throw new ApiError('请求字段异常');
    return `--${boundary}\r\nContent-Disposition: form-data; name="${field.name}"\r\n\r\n${field.value}\r\n`;
  }).join('') + `--${boundary}--\r\n`;
}

export function profileImageUrl(data: Object | undefined): string {
  if (!data || typeof data !== 'object' || Array.isArray(data)) throw new ApiError('头像上传结果异常');
  const payload = data as Record<string, Object>;
  const raw = typeof payload['url'] === 'string' ? payload['url'].trim() :
    typeof payload['path'] === 'string' ? payload['path'].trim() : '';
  if (!raw || /[\x00-\x1f\x7f]/.test(raw) || raw.includes('..')) throw new ApiError('头像上传失败，请稍后重试');
  if (raw.startsWith('/')) return `${API_BASE}${raw}`;
  if (/^https:\/\/[A-Za-z0-9.-]+(?::\d+)?\/[A-Za-z0-9_./?=&%+-]+$/.test(raw)) return raw;
  throw new ApiError('头像上传结果异常');
}

export function articleText(content: string | undefined): string {
  if (typeof content !== 'string') return '';
  return content.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '')
    .replace(/<\/(p|div|h[1-6]|li)>|<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, '').replace(/&nbsp;/g, ' ').replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"').trim();
}

export function safeArticleImage(value: string): string {
  const source = value.trim();
  const path = source.startsWith(`${API_BASE}/attachment/`) ? source.slice(API_BASE.length) : source;
  // Only public attachment files; never send image requests to private APIs or third-party hosts.
  if (!/^\/attachment\/[A-Za-z0-9_./-]+$/.test(path) || path.includes('..')) return '';
  return `${API_BASE}${path}`;
}

export function articleBlocks(content: string | undefined): ArticleBlock[] {
  if (typeof content !== 'string' || !content.trim()) return [];
  const clean = content.replace(/<script\b[^>]*>[\s\S]*?<\/script>/gi, '')
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/gi, '');
  const result: ArticleBlock[] = [];
  clean.split(/(<img\b[^>]*>)/gi).forEach((part: string) => {
    if (/^<img\b/i.test(part)) {
      const src = part.match(/\bsrc\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i);
      const alt = part.match(/\balt\s*=\s*(?:"([^"]*)"|'([^']*)')/i);
      const url = safeArticleImage(src ? src[1] || src[2] || src[3] || '' : '');
      result.push({ id: `block-${result.length}`, kind: url ? 'image' : 'unavailable', url: url,
        text: articleText(alt ? alt[1] || alt[2] : '').slice(0, 240) || '文章配图' });
    } else {
      const text = articleText(part);
      if (text) result.push({ id: `block-${result.length}`, kind: 'text', text: text, url: '' });
    }
  });
  return result;
}
