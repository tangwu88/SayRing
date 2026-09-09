// Register an independent international application before enabling this channel.
export const WECHAT_APP_ID: string = '';
export const WECHAT_AUTH_RESULT_KEY: string = 'saydian.wechat.auth.result';
export const WECHAT_AUTH_MAX_AGE_MS: number = 10 * 60 * 1000;

export interface WechatAuthResult {
  status: 'success' | 'error';
  code: string;
  state: string;
  openId: string;
  message: string;
}

export function buildWechatState(now: number, nonce: string): string {
  const cleanNonce = nonce.replace(/[^A-Za-z0-9-]/g, '').slice(0, 64);
  if (!Number.isSafeInteger(now) || now <= 0 || cleanNonce.length < 16) return '';
  return `sd_${now}_${cleanNonce}`;
}

export function isFreshWechatState(state: string, expected: string, now: number): boolean {
  if (!state || state !== expected || !Number.isSafeInteger(now) || now <= 0) return false;
  const match = state.match(/^sd_([0-9]{13})_[A-Za-z0-9-]{16,64}$/);
  if (!match) return false;
  const startedAt = Number(match[1]);
  return Number.isSafeInteger(startedAt) && startedAt <= now + 60000 && now - startedAt <= WECHAT_AUTH_MAX_AGE_MS;
}

export function parseWechatAuthResult(value: string): WechatAuthResult | undefined {
  if (!value || value.length > 4096) return undefined;
  try {
    const parsed = JSON.parse(value) as WechatAuthResult;
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed) ||
      (parsed.status !== 'success' && parsed.status !== 'error') ||
      typeof parsed.code !== 'string' || typeof parsed.state !== 'string' || typeof parsed.openId !== 'string' ||
      typeof parsed.message !== 'string' || parsed.code.length > 1024 || parsed.state.length > 256 ||
      parsed.openId.length > 128 || parsed.message.length > 160) return undefined;
    return {
      status: parsed.status,
      code: parsed.code,
      state: parsed.state,
      openId: parsed.openId,
      message: parsed.message
    };
  } catch { return undefined; }
}

export function wechatAuthErrorMessage(code: number): string {
  if (code === -2) return '已取消微信登录';
  if (code === -4) return '未同意微信授权';
  if (code === -5) return '当前微信版本不支持授权登录';
  return '微信登录失败，请重试';
}
