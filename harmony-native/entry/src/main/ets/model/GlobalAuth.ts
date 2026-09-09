import { ApiError, validateStoredSession } from './Contracts';
import type { Session, Envelope, MemberProfile } from './Contracts';

export type AuthChannel = 'email' | 'sms';
export type VerificationPurpose = 'register' | 'reset_password';
export interface GlobalAuthCapabilities {
  realm: string; defaultLocale: string; supportedLocales: string[];
  registration: { email: boolean; sms: boolean }; smsCountries: string[];
  recovery: { email: boolean; sms: boolean };
  verification: { codeLength: number; expiresIn: number; retryAfter: number };
  consentVersion: string;
  legal?: GlobalLegalDocuments;
}
export interface GlobalLegalDocument { path: string; locale: string; version: string; }
export interface GlobalLegalDocuments { userAgreement: GlobalLegalDocument; privacyPolicy: GlobalLegalDocument; }
export interface VerificationChallenge {
  challengeId: string; expiresIn: number; retryAfter: number; maskedIdentifier: string;
}
export interface GlobalSessionPayload {
  accessToken: string; refreshToken: string; expiresAt: string; member: MemberProfile;
  emailMasked?: string; phoneMasked?: string; locale?: string;
}
interface GlobalMemberProfile {
  id: string; nickname: string; avatarUrl?: string; gender?: string; birthday?: string;
  heightCm?: number; weightKg?: number; emailMasked?: string; phoneMasked?: string;
}
export function parseGlobalProfile(data: Object | undefined, memberId: string): MemberProfile {
  const value = data as GlobalMemberProfile;
  if (!value || value.id !== memberId) throw new ApiError('invalid_session', 401);
  return { id: value.id, nickname: value.nickname, head_portrait: value.avatarUrl,
    gender: value.gender === 'male' ? 1 : value.gender === 'female' ? 2 : 0,
    birthday: value.birthday, height: value.heightCm, weight: value.weightKg,
    mobile: value.phoneMasked ?? '', username: value.emailMasked ?? value.phoneMasked ?? '' };
}
export interface PhoneCountry { code: string; dialCode: string; name: string; }
export const PHONE_COUNTRIES: PhoneCountry[] = [
  { code: 'US', dialCode: '+1', name: 'United States' }, { code: 'CA', dialCode: '+1', name: 'Canada' },
  { code: 'GB', dialCode: '+44', name: 'United Kingdom' }, { code: 'DE', dialCode: '+49', name: 'Deutschland' },
  { code: 'FR', dialCode: '+33', name: 'France' }, { code: 'ES', dialCode: '+34', name: 'España' },
  { code: 'JP', dialCode: '+81', name: '日本' }, { code: 'KR', dialCode: '+82', name: '대한민국' },
  { code: 'CN', dialCode: '+86', name: '中国大陆' }, { code: 'HK', dialCode: '+852', name: '香港' },
  { code: 'TW', dialCode: '+886', name: '台灣' }, { code: 'AU', dialCode: '+61', name: 'Australia' },
  { code: 'NZ', dialCode: '+64', name: 'New Zealand' }, { code: 'SG', dialCode: '+65', name: 'Singapore' },
  { code: 'IN', dialCode: '+91', name: 'India' }, { code: 'IT', dialCode: '+39', name: 'Italia' },
  { code: 'NL', dialCode: '+31', name: 'Nederland' }, { code: 'BR', dialCode: '+55', name: 'Brasil' },
  { code: 'MX', dialCode: '+52', name: 'México' }, { code: 'AE', dialCode: '+971', name: 'United Arab Emirates' }
];

export function emptyAuthCapabilities(): GlobalAuthCapabilities {
  return { realm: 'global', defaultLocale: 'en', supportedLocales: [],
    registration: { email: false, sms: false }, recovery: { email: false, sms: false }, smsCountries: [], consentVersion: '',
    verification: { codeLength: 6, expiresIn: 300, retryAfter: 60 } };
}
export function parseAuthCapabilities(data: Object | undefined): GlobalAuthCapabilities {
  const value = data as GlobalAuthCapabilities;
  if (!value || value.realm !== 'global' || !value.registration ||
    typeof value.registration.email !== 'boolean' || typeof value.registration.sms !== 'boolean' ||
    !Array.isArray(value.smsCountries) || !Array.isArray(value.supportedLocales) ||
    !value.verification || value.verification.codeLength !== 6) throw new ApiError('auth_unavailable', 503);
  return { realm: 'global', defaultLocale: 'en', supportedLocales: [...value.supportedLocales],
    registration: { email: value.registration.email && !!value.consentVersion && !!value.legal,
      sms: value.registration.sms && !!value.consentVersion && !!value.legal },
    recovery: { email: value.recovery?.email === true, sms: value.recovery?.sms === true },
    consentVersion: typeof value.consentVersion === 'string' ? value.consentVersion : '',
    legal: value.legal,
    smsCountries: value.smsCountries.filter(code => typeof code === 'string' && /^[A-Z]{2}$/.test(code)),
    verification: { codeLength: 6, expiresIn: positiveSeconds(value.verification.expiresIn, 300),
      retryAfter: positiveSeconds(value.verification.retryAfter, 60) } };
}
function positiveSeconds(value: number, fallback: number): number {
  return Number.isSafeInteger(value) && value > 0 && value <= 86400 ? value : fallback;
}
export function parseVerificationChallenge(data: Object | undefined): VerificationChallenge {
  const value = data as VerificationChallenge;
  if (!value || typeof value.challengeId !== 'string' || !/^[A-Za-z0-9_-]{8,160}$/.test(value.challengeId) ||
    typeof value.maskedIdentifier !== 'string' || !Number.isSafeInteger(value.expiresIn) || value.expiresIn <= 0 ||
    !Number.isSafeInteger(value.retryAfter) || value.retryAfter <= 0) throw new ApiError('verification_unavailable', 503);
  return { challengeId: value.challengeId, expiresIn: positiveSeconds(value.expiresIn, 300),
    retryAfter: positiveSeconds(value.retryAfter, 60), maskedIdentifier: value.maskedIdentifier.slice(0, 254) };
}
export function normalizeIdentifier(channel: AuthChannel, raw: string): string {
  const value = raw.trim();
  if (channel === 'email') {
    if (value.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value)) throw new ApiError('invalid_email', 422);
    return value.toLowerCase();
  }
  const phone = value.replace(/[ ()-]/g, '');
  if (!/^\+[1-9]\d{6,14}$/.test(phone)) throw new ApiError('invalid_phone', 422);
  return phone;
}
export function globalRegistrationValidation(identifier: string, channel: AuthChannel, code: string,
  password: string, confirmation: string, accepted: boolean): string {
  if (!accepted) return 'accept_terms';
  try { normalizeIdentifier(channel, identifier); } catch (error) { return (error as Error).message; }
  if (!/^\d{6}$/.test(code.trim())) return 'invalid_code';
  if (!validGlobalPassword(password)) return 'password_length';
  if (password !== confirmation) return 'password_mismatch';
  return '';
}
// Keep the server's bcrypt 72 UTF-8 byte ceiling. Character count alone is unsafe
// for CJK/emoji passwords. No platform or watch APIs are involved.
export function validGlobalPassword(password: string): boolean {
  if (password.length < 8) return false;
  let bytes = 0;
  for (let index = 0; index < password.length; index++) {
    const unit = password.charCodeAt(index);
    if (unit < 0x80) bytes++;
    else if (unit < 0x800) bytes += 2;
    else if (unit >= 0xd800 && unit <= 0xdbff && index + 1 < password.length &&
      password.charCodeAt(index + 1) >= 0xdc00 && password.charCodeAt(index + 1) <= 0xdfff) { bytes += 4; index++; }
    else bytes += 3;
  }
  return bytes <= 72;
}
export function parseGlobalSession(payload: Envelope, now: number, previous?: Session): Session {
  const value = payload.data as GlobalSessionPayload;
  if (!value || !value.member || typeof value.member.id !== 'string' ||
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value.member.id) ||
    typeof value.expiresAt !== 'string') throw new ApiError('invalid_session', 401);
  if (previous && previous.memberId !== value.member.id) throw new ApiError('invalid_session', 401);
  const expiresAt = Date.parse(value.expiresAt);
  if (!Number.isFinite(expiresAt) || expiresAt <= now) throw new ApiError('session_expired', 401);
  return validateStoredSession({ accessToken: value.accessToken, refreshToken: value.refreshToken,
    expiresAt, memberId: value.member.id, displayName: value.member.nickname?.trim() || 'Saydian' });
}
