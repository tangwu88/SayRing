import type { HealthValue } from './WearableContracts';
import { chinaDay, chinaDaySeconds } from './CareContracts';
import { profileImageUrl } from './Contracts';
import type { FormField, MemberProfile } from './Contracts';

export interface DisplayUnits { distance: 'km' | 'mi'; temperature: 'c' | 'f'; }

export function defaultDisplayUnits(): DisplayUnits { return { distance: 'km', temperature: 'c' }; }

export function parseDisplayUnits(distance: string, temperature: string): DisplayUnits {
  return { distance: distance === 'mi' ? 'mi' : 'km', temperature: temperature === 'f' ? 'f' : 'c' };
}

export function displayHealthValue(value: HealthValue, units: DisplayUnits): HealthValue {
  if (units.temperature === 'f' && ['℃', '°C'].includes(value.unit)) {
    return { name: value.name, value: value.value * 1.8 + 32, unit: '℉' };
  }
  if (units.distance === 'mi' && ['km', '公里', '千米'].includes(value.unit)) {
    return { name: value.name, value: value.value / 1.609344, unit: 'mi' };
  }
  return { name: value.name, value: value.value, unit: value.unit };
}

export function displayNumber(value: number): string {
  if (!Number.isFinite(value)) return '--';
  return Number.isInteger(value) ? String(value) : value.toFixed(1);
}

export interface ProfileDraft {
  nickname: string; gender: number; birthday: string; height: string; weight: string;
}

export function profileDraftError(draft: ProfileDraft): string {
  if (!draft.nickname.trim() || draft.nickname.trim().length > 30) return '请填写 1～30 字的昵称';
  if (![0, 1, 2].includes(draft.gender)) return '请选择性别';
  try { chinaDaySeconds(draft.birthday); } catch { return '请选择有效生日'; }
  if (draft.birthday > chinaDay()) return '生日不能晚于今天';
  if (!draft.height.trim() || !Number.isFinite(Number(draft.height)) || Number(draft.height) < 30 || Number(draft.height) > 250) return '请填写有效身高（30～250 cm）';
  if (!draft.weight.trim() || !Number.isFinite(Number(draft.weight)) || Number(draft.weight) < 2 || Number(draft.weight) > 300) return '请填写有效体重（2～300 kg）';
  return '';
}

export function profileSaveMismatches(fields: FormField[], profile: MemberProfile): string[] {
  const values: Record<string, string | number | undefined> = { nickname: profile.nickname, gender: profile.gender,
    birthday: profile.birthday, height: profile.height, weight: profile.weight, head_portrait: profile.head_portrait };
  const labels: Record<string, string> = { nickname: '昵称', gender: '性别', birthday: '生日', height: '身高',
    weight: '体重', head_portrait: '头像' };
  return fields.filter((field: FormField) => {
    const value = values[field.name];
    // Missing fields are not zero, and an unsubmitted field is never compared or written back.
    if ((typeof value !== 'string' && typeof value !== 'number') || String(value).trim() === '') return true;
    if (['gender', 'height', 'weight'].includes(field.name)) {
      return !Number.isFinite(Number(value)) || Number(value) !== Number(field.value);
    }
    if (field.name === 'head_portrait') {
      try { return profileImageUrl({ url: String(value) }) !== profileImageUrl({ url: field.value }); }
      catch { return true; }
    }
    return String(value).trim() !== field.value;
  }).map((field: FormField) => labels[field.name]);
}

export const FEEDBACK_TYPES: string[] = ['功能建议', '设备连接', '数据问题', '商城订单'];

export function feedbackError(category: string, content: string, contact: string): string {
  if (!FEEDBACK_TYPES.includes(category)) return '请选择问题类型';
  if (content.trim().length < 5 || content.trim().length > 500) return '请填写 5～500 字的问题说明';
  if (contact.trim().length > 100) return '联系方式请控制在 100 字以内';
  return '';
}
