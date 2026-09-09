// International builds have an independent application sandbox and server realm.
export const GLOBAL_ORIGIN: string = 'https://app.saydian.cn';
export const GLOBAL_PREFIX: string = '/global';
export const GLOBAL_API: string = '/api/saydian-app/v2';
export const GLOBAL_BUNDLE: string = 'cn.saydian.app.global.hm';
export const GLOBAL_WECHAT_ENABLED: boolean = false;
export const GLOBAL_PUSH_ENABLED: boolean = false;
export const GLOBAL_PAYMENTS_ENABLED: boolean = false;

export function globalApiPath(path: string): string { return `${GLOBAL_API}${path}`; }

export function internationalUrl(path: string): string {
  if (!path.startsWith('/api/') || path.includes('://') || path.includes('..') || path.includes('\\')) {
    throw new Error('Invalid API destination');
  }
  return `${GLOBAL_ORIGIN}${GLOBAL_PREFIX}${path}`;
}
