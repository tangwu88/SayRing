import { ApiError, validateStoredSession } from './Contracts';
import type { Session } from './Contracts';
import { normalizeIdentifier } from './GlobalAuth';
import type { AuthChannel, GlobalAuthCapabilities, VerificationChallenge } from './GlobalAuth';
import { careGroupOptions } from './CareContracts';
import type { CareOption, CareShareSettings } from './CareContracts';

export const RING_THEME = {
  ink: '#1E2933', muted: '#687181', canvas: '#F7F7F5', line: '#E8EBF0',
  primary: '#285C68', primaryDark: '#244BA8', primarySoft: '#E8F1F1',
  cyan: '#149FB3', violet: '#6979A5', danger: '#B3261E'
};
export const RING_CUSTOMER_SERVICE: string = 'https://work.weixin.qq.com/kfid/kfcae32196355fde04c';

export function ringLoginIdentifier(channel: AuthChannel, value: string): string {
  if (channel === 'email') return normalizeIdentifier(channel, value);
  const phone = value.trim().replace(/^\+86/, '');
  if (!/^1[3-9]\d{9}$/.test(phone)) throw new ApiError('请输入正确的11位中国大陆手机号', 422);
  return `+86${phone}`;
}
export function ringLoginAvailable(caps: GlobalAuthCapabilities, channel: AuthChannel): boolean {
  return caps.login?.[channel] === true && caps.login?.explicitRegistrationCodeLogin === true && !!caps.consentVersion && !!caps.legal &&
    (channel !== 'sms' || caps.smsCountries.includes('CN'));
}
export function ringLoginFailure(error: Error, password: boolean): string {
  if (['invalid_password', 'password_length'].includes(error.message)) return '密码至少8个字符；英文字母和数字最多72个，其他字符可用长度更短';
  if (error instanceof ApiError && error.status === 401) return password ? '账号或密码不正确，请重新输入' : '验证码不正确或已失效，请重新获取';
  return error.message || '登录未完成，请稍后重试';
}
export function parseRingLoginChallenge(payload: Object): VerificationChallenge {
  const value = payload as Record<string, Object>;
  if (!value || typeof value['challengeId'] !== 'string' || !/^[A-Za-z0-9_-]{8,160}$/.test(String(value['challengeId'])) ||
    !Number.isSafeInteger(value['expiresIn']) || Number(value['expiresIn']) <= 0 || Number(value['expiresIn']) > 86400 ||
    !Number.isSafeInteger(value['retryAfter']) || Number(value['retryAfter']) < 0 || Number(value['retryAfter']) > 86400) {
    throw new ApiError('验证码服务返回异常，请重试', 503);
  }
  return { challengeId: String(value['challengeId']), expiresIn: Number(value['expiresIn']),
    retryAfter: Number(value['retryAfter']), maskedIdentifier: typeof value['maskedIdentifier'] === 'string' ? String(value['maskedIdentifier']).slice(0, 254) : '' };
}
export function parseRingLoginSession(payload: Object, now: number): Session {
  const value = payload as Record<string, Object>, user = value?.['user'] as Record<string, Object>;
  const expiry = typeof value?.['expiresAt'] === 'string' ? Date.parse(String(value['expiresAt'])) : NaN;
  if (!user || user['phoneTestMode'] === true || typeof user['id'] !== 'string' ||
    typeof value['token'] !== 'string' || typeof value['refreshToken'] !== 'string' ||
    !String(value['refreshToken']) || !Number.isFinite(expiry) || expiry <= now) throw new ApiError('登录身份无效，请重新验证', 401);
  return validateStoredSession({ accessToken: String(value['token']), refreshToken: String(value['refreshToken']),
    memberId: String(user['id']), displayName: typeof user['nickname'] === 'string' ? String(user['nickname']) : 'Say Ring 用户', expiresAt: expiry });
}

export interface HomeCardLayout { order: string[]; hidden: string[]; }
export function parseHomeCardLayout(value: Object | undefined): HomeCardLayout {
  const root = value as Record<string, Object>;
  const clean = (items: Object | undefined): string[] => Array.isArray(items) ?
    [...new Set((items as string[]).filter(key => typeof key === 'string' && /^[A-Za-z]{2,32}$/.test(key)))].slice(0, 30) : [];
  return { order: clean(root?.['order']), hidden: clean(root?.['hidden']) };
}
export function orderedHomeCards(available: string[], layout: HomeCardLayout, includeHidden: boolean = false): string[] {
  const unique = [...new Set([...layout.order, ...available])].filter(key => available.includes(key));
  return unique.filter(key => includeHidden || !layout.hidden.includes(key));
}

// Hide unsupported switches without silently revoking previously stored grants.
export function ringCareOptions(daily: boolean, available: string[]): CareOption[] {
  const map: Record<string, string> = { steps: 'activity', reliang: 'activity', juli: 'activity', sleep: 'sleep',
    bloodPressure: 'pressure', bloodGlucose: 'glucose', bloodOxygen: 'oxygen', bodyTemperature: 'temperature',
    ecg: 'ecg', heartReat: 'heart', HRV: 'hrv', bodycomposition: 'bodyComposition', bloodcomposition: 'bloodComponents' };
  return careGroupOptions(daily).filter(option => available.includes(map[option.key]));
}
export function toggleRingCareGroup(settings: CareShareSettings, keys: string[]): CareShareSettings {
  if (!keys.length) return { enabled: [...settings.enabled], unknown: [...settings.unknown] };
  const all = keys.every(key => settings.enabled.includes(key));
  const remaining = settings.enabled.filter(key => !keys.includes(key));
  return { enabled: all ? remaining : [...remaining, ...keys], unknown: [...settings.unknown] };
}
